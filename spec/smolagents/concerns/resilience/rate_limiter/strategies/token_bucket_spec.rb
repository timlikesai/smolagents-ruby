require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::TokenBucket do
  let(:strategy) { described_class.new(rate: 10, burst: 20) }

  describe "#initialize" do
    it "inherits from Base" do
      expect(strategy).to be_a(Smolagents::Concerns::RateLimiter::Strategies::Base)
    end

    it "initializes tokens to burst" do
      expect(strategy.tokens).to eq(20.0)
    end

    it "initializes last_refill timestamp as float" do
      expect(strategy.instance_variable_get(:@last_refill)).to be_a(Float)
    end

    it "initializes mutex for thread safety" do
      expect(strategy.instance_variable_get(:@mutex)).to be_a(Mutex)
    end
  end

  describe "#allow?" do
    it "returns true when tokens available" do
      expect(strategy.allow?).to be true
    end

    it "returns false when no tokens" do
      strategy.instance_variable_set(:@tokens, 0.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(strategy.allow?).to be false
    end

    it "does not consume tokens" do
      initial = strategy.tokens
      strategy.allow?
      after = strategy.tokens

      expect(after).to eq(initial)
    end

    it "refills tokens over time" do
      # Deplete bucket
      strategy.instance_variable_set(:@tokens, 0.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f - 1.0)

      # Should have refilled
      result = strategy.allow?
      expect(result).to be true
    end
  end

  describe "#acquire!" do
    it "consumes one token" do
      initial = strategy.tokens
      strategy.acquire!
      after = strategy.tokens

      expect(after).to be < initial
    end

    it "returns true when token available" do
      expect(strategy.acquire!).to be true
    end

    it "returns false when no tokens" do
      strategy.instance_variable_set(:@tokens, 0.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(strategy.acquire!).to be false
    end

    it "allows fractional tokens" do
      # Token bucket allows fractional tokens
      10.times { strategy.acquire! }

      result = strategy.acquire!
      expect(result).to be true
    end

    it "handles exact token consumption" do
      strategy.instance_variable_set(:@tokens, 2.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(strategy.acquire!).to be true
      expect(strategy.acquire!).to be true
      expect(strategy.acquire!).to be false
    end
  end

  describe "#retry_after" do
    context "when tokens available" do
      it "returns 0" do
        expect(strategy.retry_after).to eq(0.0)
      end
    end

    context "when no tokens" do
      before do
        strategy.instance_variable_set(:@tokens, 0.0)
        strategy.instance_variable_set(:@last_refill, Time.now.to_f)
      end

      it "returns positive value" do
        expect(strategy.retry_after).to be > 0
      end

      it "calculates time to next token" do
        retry_after = strategy.retry_after
        # At rate 10, should take 0.1s per token
        expect(retry_after).to be_within(0.15).of(0.1)
      end
    end

    it "decreases as tokens refill" do
      strategy.instance_variable_set(:@tokens, 0.0)
      now = Time.now.to_f
      strategy.instance_variable_set(:@last_refill, now)

      initial_retry = strategy.retry_after

      # Simulate time passing by adjusting last_refill instead of sleeping
      strategy.instance_variable_set(:@last_refill, now - 0.05)

      later_retry = strategy.retry_after

      expect(later_retry).to be < initial_retry
    end
  end

  describe "#reset!" do
    before do
      10.times { strategy.acquire! }
    end

    it "restores tokens to burst" do
      strategy.reset!
      expect(strategy.tokens).to eq(20.0)
    end

    it "resets last_refill time" do
      old_time = strategy.instance_variable_get(:@last_refill)
      strategy.reset!
      new_time = strategy.instance_variable_get(:@last_refill)

      expect(new_time).to be >= old_time
    end
  end

  describe "token bucket behavior" do
    it "starts with full bucket" do
      s = described_class.new(rate: 10, burst: 20)
      expect(s.tokens).to eq(20.0)
    end

    it "allows burst consumption" do
      results = []
      20.times { results << strategy.acquire! }

      expect(results).to all(be true)
    end

    it "blocks additional requests after burst" do
      20.times { strategy.acquire! }
      strategy.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(strategy.acquire!).to be false
    end

    it "refills tokens at configured rate" do
      strategy.instance_variable_set(:@tokens, 0.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f - 1.0)

      # Trigger refill by checking allow?
      strategy.allow?

      refilled = strategy.tokens
      expect(refilled).to be > 0
    end
  end

  describe "refill rate" do
    it "uses rate parameter for refill" do
      s = described_class.new(rate: 100, burst: 1000)

      s.instance_variable_set(:@tokens, 0.0)
      s.instance_variable_set(:@last_refill, Time.now.to_f - 1.0)

      # Trigger refill
      s.allow?

      # Should have refilled at 100 tokens per second
      expect(s.tokens).to be > 0
    end

    it "caps tokens at burst" do
      strategy.instance_variable_set(:@tokens, 0.0)
      strategy.instance_variable_set(:@last_refill, Time.now.to_f - 10.0)

      # Trigger refill
      strategy.allow?
      tokens = strategy.tokens

      # Even after long time, tokens capped at burst
      expect(tokens).to eq(20.0)
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

      # At most burst should succeed immediately
      expect(results.count(true)).to be <= 25 # Some tolerance for refill
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
      expect(results.size).to eq(25)
    end

    it "maintains token consistency under contention" do
      threads = Array.new(5) do
        Thread.new do
          strategy.acquire!
        end
      end

      threads.each(&:join)

      # Tokens should never go below 0
      expect(strategy.tokens).to be >= 0
    end
  end

  describe "edge cases" do
    it "handles rate=1 (one token per second)" do
      s = described_class.new(rate: 1, burst: 2)
      expect(s.acquire!).to be true
      expect(s.acquire!).to be true
      expect(s.acquire!).to be false
    end

    it "handles high rate" do
      s = described_class.new(rate: 1000, burst: 10_000)
      results = []
      100.times { results << s.acquire! }
      expect(results).to all(be true)
    end

    it "handles fractional rates" do
      s = described_class.new(rate: 0.5, burst: 1)
      expect(s.acquire!).to be true
    end

    it "handles zero tokens initially with no-op" do
      s = described_class.new(rate: 10, burst: 0)
      # With burst 0, no tokens available
      expect(s.acquire!).to be false
    end
  end

  describe "comparison with other strategies" do
    it "allows smoothing of traffic unlike fixed window" do
      # Token bucket smooths traffic better than fixed window
      s = described_class.new(rate: 10, burst: 20)

      # Rapid burst
      20.times { s.acquire! }
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      # Check remaining
      can_acquire = s.allow?
      # With token bucket, next token refills over time
      expect(can_acquire).to be false
    end

    it "handles sustained rate better than sliding window" do
      # Token bucket is better for sustained traffic
      s = described_class.new(rate: 10, burst: 10)

      # Consume all
      10.times { s.acquire! }

      # Simulate time passing by adjusting last_refill
      s.instance_variable_set(:@last_refill, Time.now.to_f - 0.15)

      # Should be able to acquire after simulated refill
      expect(s.allow?).to be true
    end
  end

  describe "practical usage" do
    it "simulates API rate limiting" do
      # API allows 100 requests per second with burst of 500
      s = described_class.new(rate: 100, burst: 500)

      # Rapid initial burst
      fast_results = []
      500.times { fast_results << s.acquire! }

      # Most should succeed
      expect(fast_results.count(true)).to eq(500)

      # Now requests should be rate limited
      s.instance_variable_set(:@last_refill, Time.now.to_f)
      expect(s.acquire!).to be false

      # Simulate time passing for refill
      s.instance_variable_set(:@last_refill, Time.now.to_f - 0.05)
      expect(s.allow?).to be true
    end

    it "handles sustained traffic" do
      # 10 requests per second, max burst 20
      s = described_class.new(rate: 10, burst: 20)

      # Burst at start
      burst_results = []
      20.times { burst_results << s.acquire! }
      expect(burst_results.count(true)).to eq(20)

      # Simulate time passing for refill
      s.instance_variable_set(:@last_refill, Time.now.to_f - 0.25)

      # Should allow some requests
      expect(s.allow?).to be true
    end
  end

  describe "token calculation" do
    it "tracks tokens as floats for precision" do
      s = described_class.new(rate: 10, burst: 20)
      tokens = s.tokens
      expect(tokens).to be_a(Float)
    end

    it "handles partial token consumption" do
      s = described_class.new(rate: 3, burst: 3)

      s.instance_variable_set(:@tokens, 2.5)
      expect(s.acquire!).to be true
      tokens_after = s.tokens
      expect(tokens_after).to be_within(0.1).of(1.5)
    end
  end

  describe "boundary conditions" do
    it "handles exactly 1.0 token remaining" do
      s = described_class.new(rate: 10, burst: 10)
      s.instance_variable_set(:@tokens, 1.0)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(s.allow?).to be true
      expect(s.acquire!).to be true
      expect(s.acquire!).to be false
    end

    it "handles tokens just under 1.0" do
      s = described_class.new(rate: 10, burst: 10)
      s.instance_variable_set(:@tokens, 0.99)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(s.allow?).to be false
      expect(s.acquire!).to be false
    end

    it "returns correct retry_after when tokens at 0" do
      s = described_class.new(rate: 10, burst: 10)
      s.instance_variable_set(:@tokens, 0.0)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      retry_after = s.retry_after
      # At rate 10, 1 token takes 0.1 seconds
      expect(retry_after).to be_within(0.05).of(0.1)
    end

    it "returns correct retry_after when tokens partially depleted" do
      s = described_class.new(rate: 10, burst: 10)
      s.instance_variable_set(:@tokens, 0.5)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      retry_after = s.retry_after
      # Need 0.5 more tokens at rate 10 = 0.05 seconds
      expect(retry_after).to be_within(0.05).of(0.05)
    end

    it "handles large time gaps without overflow" do
      s = described_class.new(rate: 10, burst: 10)
      s.instance_variable_set(:@tokens, 0.0)
      # 1 year ago
      s.instance_variable_set(:@last_refill, Time.now.to_f - (365 * 24 * 60 * 60))

      expect(s.allow?).to be true
      expect(s.tokens).to eq(10.0) # Capped at burst
    end

    it "handles very small rates" do
      s = described_class.new(rate: 0.001, burst: 1)
      s.instance_variable_set(:@tokens, 0.0)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      # At rate 0.001, need 1000 seconds for 1 token
      retry_after = s.retry_after
      expect(retry_after).to be_within(100).of(1000)
    end

    it "handles very large rates" do
      s = described_class.new(rate: 1_000_000, burst: 1_000_000)
      # Should work without overflow
      expect { s.acquire! }.not_to raise_error
      expect(s.tokens).to be >= 0
    end
  end

  describe "negative scenario handling" do
    it "never returns negative retry_after" do
      s = described_class.new(rate: 10, burst: 10)
      # Even with full tokens
      expect(s.retry_after).to be >= 0.0
    end

    it "never allows negative tokens" do
      s = described_class.new(rate: 10, burst: 10)
      # Force negative tokens scenario
      s.instance_variable_set(:@tokens, -5.0)
      s.instance_variable_set(:@last_refill, Time.now.to_f)

      expect(s.acquire!).to be false
      expect(s.retry_after).to be > 0
    end
  end

  describe "rate limiter contract" do
    it "satisfies basic rate limiter interface" do
      s = described_class.new(rate: 10, burst: 10)

      # Must respond to core methods
      expect(s).to respond_to(:allow?)
      expect(s).to respond_to(:acquire!)
      expect(s).to respond_to(:retry_after)
      expect(s).to respond_to(:reset!)
    end

    it "allow? returns boolean" do
      s = described_class.new(rate: 10, burst: 10)
      expect(s.allow?).to be(true).or be(false)
    end

    it "acquire! returns boolean" do
      s = described_class.new(rate: 10, burst: 10)
      expect(s.acquire!).to be(true).or be(false)
    end

    it "retry_after returns non-negative number" do
      s = described_class.new(rate: 10, burst: 10)
      expect(s.retry_after).to be_a(Numeric)
      expect(s.retry_after).to be >= 0
    end
  end
end
