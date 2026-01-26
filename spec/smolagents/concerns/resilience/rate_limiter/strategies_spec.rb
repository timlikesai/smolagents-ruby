require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies do
  describe ".for_policy" do
    it "creates token bucket strategy" do
      policy = Smolagents::Security::RateLimitPolicy.new(
        requests_per_second: 2.0,
        burst_size: 5,
        strategy: :token_bucket,
        scope: :tool
      )

      strategy = described_class.for_policy(policy)

      expect(strategy).to be_a(described_class::TokenBucket)
      expect(strategy.rate).to eq(2.0)
      expect(strategy.burst).to eq(5)
    end

    it "creates sliding window strategy" do
      policy = Smolagents::Security::RateLimitPolicy.new(
        requests_per_second: 1.0,
        burst_size: 3,
        strategy: :sliding_window,
        scope: :tool
      )

      strategy = described_class.for_policy(policy)

      expect(strategy).to be_a(described_class::SlidingWindow)
    end

    it "creates fixed window strategy" do
      policy = Smolagents::Security::RateLimitPolicy.new(
        requests_per_second: 1.0,
        burst_size: 3,
        strategy: :fixed_window,
        scope: :tool
      )

      strategy = described_class.for_policy(policy)

      expect(strategy).to be_a(described_class::FixedWindow)
    end

    it "returns nil for disabled policy" do
      policy = Smolagents::Security::RateLimitPolicy.unlimited

      expect(described_class.for_policy(policy)).to be_nil
    end

    it "raises for unknown strategy" do
      policy = Smolagents::Security::RateLimitPolicy.new(
        requests_per_second: 1.0,
        burst_size: 3,
        strategy: :unknown,
        scope: :tool
      )

      expect { described_class.for_policy(policy) }.to raise_error(ArgumentError, /Unknown strategy/)
    end
  end

  describe ".create" do
    it "creates strategy by name" do
      strategy = described_class.create(:token_bucket, rate: 2.0, burst: 5)

      expect(strategy).to be_a(described_class::TokenBucket)
    end

    it "raises for unknown strategy" do
      expect { described_class.create(:unknown, rate: 1.0, burst: 1) }
        .to raise_error(ArgumentError, /Unknown strategy/)
    end
  end
end

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::TokenBucket do
  subject(:bucket) { described_class.new(rate: 10.0, burst: 5) }

  describe "#allow?" do
    it "allows requests up to burst size" do
      5.times { expect(bucket.acquire!).to be true }
    end

    it "denies when bucket empty" do
      5.times { bucket.acquire! }
      expect(bucket.allow?).to be false
    end
  end

  describe "#acquire!" do
    it "consumes tokens" do
      expect(bucket.acquire!).to be true
      expect(bucket.tokens).to be < 5.0
    end

    it "refills over time" do
      5.times { bucket.acquire! }
      expect(bucket.allow?).to be false

      # Simulate time passing by resetting last_refill
      bucket.instance_variable_set(:@last_refill, Time.now.to_f - 0.5)

      expect(bucket.allow?).to be true
    end
  end

  describe "#retry_after" do
    it "returns 0 when tokens available" do
      expect(bucket.retry_after).to eq(0.0)
    end

    it "returns time until token available" do
      5.times { bucket.acquire! }
      expect(bucket.retry_after).to be > 0
      expect(bucket.retry_after).to be <= 0.1 # ~0.1s for 1 token at 10/s
    end
  end

  describe "#reset!" do
    it "restores full capacity" do
      5.times { bucket.acquire! }
      bucket.reset!
      expect(bucket.tokens).to eq(5.0)
    end
  end
end

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::SlidingWindow do
  subject(:window) { described_class.new(rate: 2.0, burst: 4) }

  describe "#allow?" do
    it "allows requests up to burst" do
      4.times { expect(window.acquire!).to be true }
      expect(window.allow?).to be false
    end
  end

  describe "#acquire!" do
    it "records timestamps" do
      window.acquire!
      expect(window.timestamps.size).to eq(1)
    end

    it "prunes old timestamps" do
      4.times { window.acquire! }
      expect(window.acquire!).to be false

      # Simulate time passing
      old_time = Time.now.to_f - window.window_size - 0.1
      window.instance_variable_set(:@timestamps, [old_time])

      expect(window.acquire!).to be true
    end
  end

  describe "#retry_after" do
    it "returns 0 when under limit" do
      expect(window.retry_after).to eq(0.0)
    end

    it "returns time until window slides" do
      4.times { window.acquire! }
      expect(window.retry_after).to be > 0
    end
  end

  describe "#window_size" do
    it "calculates from burst and rate" do
      expect(window.window_size).to eq(2.0) # 4 burst / 2 rate = 2s
    end
  end

  describe "#reset!" do
    it "clears timestamps" do
      3.times { window.acquire! }
      window.reset!
      expect(window.timestamps).to be_empty
    end
  end
end

RSpec.describe Smolagents::Concerns::RateLimiter::Strategies::FixedWindow do
  subject(:window) { described_class.new(rate: 2.0, burst: 4) }

  describe "#allow?" do
    it "allows requests up to burst" do
      4.times { expect(window.acquire!).to be true }
      expect(window.allow?).to be false
    end
  end

  describe "#acquire!" do
    it "increments counter" do
      window.acquire!
      expect(window.count).to eq(1)
    end

    it "resets at window boundary" do
      4.times { window.acquire! }
      expect(window.acquire!).to be false

      # Simulate window expiry
      window.instance_variable_set(:@window_start, Time.now.to_f - window.window_size - 0.1)

      expect(window.acquire!).to be true
      expect(window.count).to eq(1)
    end
  end

  describe "#retry_after" do
    it "returns 0 when under limit" do
      expect(window.retry_after).to eq(0.0)
    end

    it "returns time until next window" do
      4.times { window.acquire! }
      expect(window.retry_after).to be > 0
      expect(window.retry_after).to be <= window.window_size
    end
  end

  describe "#window_size" do
    it "calculates from burst and rate" do
      expect(window.window_size).to eq(2.0)
    end
  end

  describe "#reset!" do
    it "clears counter and starts new window" do
      3.times { window.acquire! }
      window.reset!
      expect(window.count).to eq(0)
    end
  end
end
