require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::FixedWindow do
  let(:strategy) { described_class.new(rate: 10, burst: 20) }

  describe "#initialize" do
    it "inherits from Base" do
      expect(strategy).to be_a(Smolagents::Concerns::RateLimiter::Strategies::Base)
    end

    it "initializes count to 0" do
      expect(strategy.count).to eq(0)
    end

    it "sets window start time as float" do
      expect(strategy.instance_variable_get(:@window_start)).to be_a(Float)
    end

    it "initializes mutex for thread safety" do
      expect(strategy.instance_variable_get(:@mutex)).to be_a(Mutex)
    end
  end

  describe "#allow?" do
    it "returns true when count under burst" do
      expect(strategy.allow?).to be true
    end

    it "returns false when count at burst" do
      20.times { strategy.acquire! }
      expect(strategy.allow?).to be false
    end

    it "does not consume capacity" do
      strategy.allow?
      expect(strategy.count).to eq(0)
    end

    it "resets after window expires" do
      # Set expired window
      old_time = Time.now.to_f - 100
      strategy.instance_variable_set(:@window_start, old_time)
      20.times { strategy.instance_variable_set(:@count, strategy.count + 1) }

      result = strategy.allow?

      # Should have reset window
      expect(result).to be true
    end
  end

  describe "#acquire!" do
    it "increments count" do
      strategy.acquire!
      expect(strategy.count).to eq(1)
    end

    it "returns true when acquired" do
      expect(strategy.acquire!).to be true
    end

    it "returns false when at burst limit" do
      20.times { strategy.acquire! }
      expect(strategy.acquire!).to be false
    end

    it "maintains count consistency" do
      20.times { strategy.acquire! }
      expect(strategy.count).to eq(20)
    end
  end

  describe "#retry_after" do
    context "when count under burst" do
      it "returns 0" do
        expect(strategy.retry_after).to eq(0.0)
      end
    end

    context "when count at burst" do
      before do
        20.times { strategy.acquire! }
      end

      it "returns time until next window" do
        retry_after = strategy.retry_after
        expect(retry_after).to be > 0
      end

      it "returns less than or equal to window size" do
        retry_after = strategy.retry_after
        expect(retry_after).to be <= strategy.window_size
      end
    end
  end

  describe "#reset!" do
    before do
      strategy.acquire!
      strategy.acquire!
    end

    it "resets count to 0" do
      strategy.reset!
      expect(strategy.count).to eq(0)
    end

    it "resets window start time" do
      old_time = strategy.instance_variable_get(:@window_start)
      strategy.reset!
      new_time = strategy.instance_variable_get(:@window_start)

      expect(new_time).to be >= old_time
    end
  end

  describe "fixed window behavior" do
    it "allows burst requests at start of window" do
      results = []
      20.times { results << strategy.acquire! }

      expect(results).to all(be true)
      expect(strategy.count).to eq(20)
    end

    it "blocks when window exhausted" do
      20.times { strategy.acquire! }

      expect(strategy.acquire!).to be false
    end

    it "refills on next window" do
      # Exhaust current window
      20.times { strategy.acquire! }
      expect(strategy.acquire!).to be false

      # Move time forward past window
      strategy.instance_variable_set(:@window_start, Time.now.to_f - 100)

      # Should allow requests again
      expect(strategy.acquire!).to be true
    end
  end

  describe "window timing" do
    it "calculates window duration from rate and burst" do
      s = described_class.new(rate: 10, burst: 100)
      expect(s.window_size).to eq(10.0)
    end

    it "allows requests within window" do
      start_time = Time.now.to_f - 0.5 # Recent window start
      strategy.instance_variable_set(:@window_start, start_time)

      expect(strategy.acquire!).to be true
    end

    it "resets after window expires" do
      old_time = Time.now.to_f - strategy.window_size - 1
      strategy.instance_variable_set(:@count, 20)
      strategy.instance_variable_set(:@window_start, old_time)

      expect(strategy.acquire!).to be true
      expect(strategy.count).to eq(1)
    end
  end

  describe "edge cases" do
    it "handles rate=1 (one request per window)" do
      s = described_class.new(rate: 1, burst: 1)
      expect(s.acquire!).to be true
      expect(s.acquire!).to be false
    end

    it "handles high rate (many requests per window)" do
      s = described_class.new(rate: 1000, burst: 1000)
      results = []
      100.times { results << s.acquire! }
      expect(results).to all(be true)
    end

    it "handles burst > rate" do
      s = described_class.new(rate: 5, burst: 100)
      results = []
      100.times { results << s.acquire! }
      expect(results.count(true)).to eq(100)
      expect(s.acquire!).to be false
    end
  end

  describe "thread safety" do
    it "handles concurrent acquire requests" do
      results = []
      threads = Array.new(10) do
        Thread.new do
          5.times { results << strategy.acquire! }
        end
      end

      threads.each(&:join)

      # At most 20 should succeed
      expect(results.count(true)).to be <= 20
    end
  end

  describe "window state management" do
    it "initializes with current time" do
      strategy = described_class.new(rate: 10, burst: 20)
      window_start = strategy.instance_variable_get(:@window_start)
      expect(window_start).to be_a(Float)
      expect(window_start).to be_within(1).of(Time.now.to_f)
    end

    it "advances window when expired" do
      initial_window = strategy.instance_variable_get(:@window_start)

      # Move time forward past window
      strategy.instance_variable_set(:@window_start, Time.now.to_f - 100)
      strategy.instance_variable_set(:@count, 20)

      strategy.allow?

      new_window = strategy.instance_variable_get(:@window_start)
      expect(new_window).to be > initial_window
    end
  end

  describe "integration with rate limiting" do
    it "implements fixed window rate limiting" do
      s = described_class.new(rate: 5, burst: 10)

      # Acquire all tokens
      10.times { expect(s.acquire!).to be true }

      # No more tokens
      expect(s.acquire!).to be false

      # Check when we can retry
      retry_time = s.retry_after
      expect(retry_time).to be > 0

      # After window passes
      s.instance_variable_set(:@window_start, Time.now.to_f - 10)
      expect(s.acquire!).to be true
    end
  end

  describe "comparisons with burst" do
    context "with burst = rate" do
      let(:balanced) { described_class.new(rate: 10, burst: 10) }

      it "allows exactly rate requests per window" do
        10.times { expect(balanced.acquire!).to be true }
        expect(balanced.acquire!).to be false
      end
    end

    context "with burst > rate" do
      let(:generous) { described_class.new(rate: 10, burst: 50) }

      it "allows burst requests in one window" do
        50.times { expect(generous.acquire!).to be true }
        expect(generous.acquire!).to be false
      end
    end

    context "with burst < rate" do
      let(:restrictive) { described_class.new(rate: 100, burst: 5) }

      it "limits requests to burst even in high-rate window" do
        5.times { expect(restrictive.acquire!).to be true }
        expect(restrictive.acquire!).to be false
      end
    end
  end
end
