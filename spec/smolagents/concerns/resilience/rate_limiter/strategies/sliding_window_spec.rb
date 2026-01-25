require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::SlidingWindow do
  let(:strategy) { described_class.new(rate: 10, burst: 20) }

  describe "#initialize" do
    it "inherits from Base" do
      expect(strategy).to be_a(Smolagents::Concerns::RateLimiter::Strategies::Base)
    end

    it "initializes timestamps array" do
      expect(strategy.timestamps).to be_a(Array)
      expect(strategy.timestamps).to be_empty
    end

    it "initializes mutex for thread safety" do
      expect(strategy.instance_variable_get(:@mutex)).to be_a(Mutex)
    end
  end

  describe "#allow?" do
    it "returns true when under rate limit" do
      expect(strategy.allow?).to be true
    end

    it "returns false after exceeding burst" do
      20.times { strategy.acquire! }

      expect(strategy.allow?).to be false
    end

    it "does not modify timestamps when checking" do
      initial_size = strategy.timestamps.size
      strategy.allow?
      final_size = strategy.timestamps.size

      expect(final_size).to eq(initial_size)
    end

    it "prunes expired timestamps when checking" do
      old_time = Time.now.to_f - (strategy.window_size + 1)
      recent_time = Time.now.to_f

      strategy.instance_variable_get(:@timestamps) << old_time
      strategy.instance_variable_get(:@timestamps) << recent_time

      strategy.allow?

      # Old timestamp should be pruned
      timestamps = strategy.timestamps
      expect(timestamps.none? { |t| t < old_time + 0.1 }).to be true
    end
  end

  describe "#acquire!" do
    it "records timestamp" do
      strategy.acquire!
      expect(strategy.timestamps.size).to eq(1)
    end

    it "returns true when acquired" do
      expect(strategy.acquire!).to be true
    end

    it "returns false after burst exceeded" do
      20.times { strategy.acquire! }
      expect(strategy.acquire!).to be false
    end

    it "records consecutive acquisitions" do
      5.times { strategy.acquire! }
      expect(strategy.timestamps.size).to eq(5)
    end
  end

  describe "#retry_after" do
    context "when under limit" do
      it "returns 0" do
        expect(strategy.retry_after).to eq(0.0)
      end
    end

    context "when at limit" do
      before do
        20.times { strategy.acquire! }
      end

      it "returns positive value" do
        expect(strategy.retry_after).to be > 0
      end

      it "returns time until oldest request expires" do
        retry_time = strategy.retry_after
        expect(retry_time).to be <= strategy.window_size
      end
    end
  end

  describe "#reset!" do
    before do
      10.times { strategy.acquire! }
    end

    it "clears timestamps" do
      strategy.reset!
      expect(strategy.timestamps).to be_empty
    end
  end

  describe "sliding window behavior" do
    it "allows burst at start" do
      results = []
      20.times { results << strategy.acquire! }

      expect(results).to all(be true)
    end

    it "prevents requests beyond rate over window" do
      20.times { strategy.acquire! }

      # Next request should fail
      expect(strategy.acquire!).to be false
    end

    it "allows new requests after window slides" do
      20.times { strategy.acquire! }

      # Simulate time passing by setting timestamps to old times
      old_time = Time.now.to_f - strategy.window_size - 0.1
      strategy.instance_variable_set(:@timestamps, [old_time] * 20)

      # Should allow new request after pruning old timestamps
      expect(strategy.acquire!).to be true
    end

    it "maintains sliding window correctly" do
      # Add requests at current time
      5.times { strategy.acquire! }

      # Count requests in current window
      in_window = strategy.timestamps.size
      expect(in_window).to eq(5)
    end
  end

  describe "expiration handling" do
    it "removes expired entries" do
      old_time = Time.now.to_f - strategy.window_size - 1
      recent_time = Time.now.to_f

      strategy.instance_variable_get(:@timestamps) << old_time
      strategy.instance_variable_get(:@timestamps) << recent_time

      # Trigger cleanup by calling allow
      strategy.allow?

      # Old entry should be gone
      expect(strategy.timestamps.any? { |t| t < old_time + 0.1 }).to be false
    end

    it "keeps fresh entries" do
      strategy.acquire!
      initial_size = strategy.timestamps.size

      strategy.allow?

      # Recent entry should still be there
      expect(strategy.timestamps.size).to eq(initial_size)
    end
  end

  describe "rate limiting over time" do
    it "blocks when rate exceeded in window" do
      # Fill to burst
      20.times { strategy.acquire! }

      # No more room in current window
      expect(strategy.acquire!).to be false

      # Simulate time passing by setting timestamps to old times
      old_time = Time.now.to_f - strategy.window_size - 0.05
      strategy.instance_variable_set(:@timestamps, [old_time] * 20)

      # Now should allow one new request
      expect(strategy.acquire!).to be true
    end
  end

  describe "thread safety" do
    it "handles concurrent acquisitions" do
      results = []
      threads = Array.new(10) do
        Thread.new do
          5.times { results << strategy.acquire! }
        end
      end

      threads.each(&:join)

      # At most burst should succeed
      expect(results.count(true)).to be <= 20
    end

    it "handles concurrent allow checks" do
      results = []
      threads = Array.new(5) do
        Thread.new do
          5.times { results << strategy.allow? }
        end
      end

      threads.each(&:join)

      # Should not raise
      expect(results).not_to be_empty
    end
  end

  describe "window size calculations" do
    it "uses correct window size" do
      s = described_class.new(rate: 5, burst: 25)
      expect(s.window_size).to eq(5.0)
    end

    it "respects burst size" do
      s = described_class.new(rate: 10, burst: 100)
      expect(s.burst).to eq(100)
    end
  end

  describe "edge cases" do
    it "handles rate=1" do
      s = described_class.new(rate: 1, burst: 2)
      expect(s.acquire!).to be true
      expect(s.acquire!).to be true
      expect(s.acquire!).to be false
    end

    it "handles high burst" do
      s = described_class.new(rate: 1000, burst: 10_000)
      results = []
      100.times { results << s.acquire! }
      expect(results.count(true)).to eq(100)
    end

    it "handles zero rate gracefully" do
      s = described_class.new(rate: 0, burst: 1)
      # Implementation dependent
      expect { s.acquire! }.not_to raise_error
    end
  end

  describe "comparison with fixed window" do
    it "provides smoother rate limiting than fixed window" do
      # Sliding window allows distributed requests over time
      # Fixed window has hard cutoff at window boundary

      s = described_class.new(rate: 10, burst: 20)

      # Acquire 20 requests
      20.times { s.acquire! }

      # Check retry after
      retry_after = s.retry_after
      expect(retry_after).to be > 0
      expect(retry_after).to be < s.window_size
    end
  end

  describe "integration" do
    it "can be used for rate limiting API calls" do
      s = described_class.new(rate: 100, burst: 100)

      # Simulate rapid calls
      success_count = 0
      150.times do
        success_count += 1 if s.acquire!
      end

      # Should succeed about burst times
      expect(success_count).to be <= 100
    end
  end
end
