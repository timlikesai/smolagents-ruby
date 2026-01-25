require "smolagents"

RSpec.describe Smolagents::Types::RetryPolicy do
  describe ".default" do
    it "creates policy with default configuration" do
      policy = described_class.default

      expect(policy.max_attempts).to eq(3)
      expect(policy.base_interval).to eq(1.0)
      expect(policy.max_interval).to eq(30.0)
      expect(policy.backoff).to eq(:exponential)
      expect(policy.jitter).to eq(0.5)
      expect(policy.retryable_errors).not_to be_empty
    end
  end

  describe ".aggressive" do
    it "creates policy with aggressive configuration" do
      policy = described_class.aggressive

      expect(policy.max_attempts).to eq(5)
      expect(policy.base_interval).to eq(0.5)
      expect(policy.max_interval).to eq(15.0)
      expect(policy.backoff).to eq(:exponential)
      expect(policy.jitter).to eq(0.3)
    end
  end

  describe ".conservative" do
    it "creates policy with conservative configuration" do
      policy = described_class.conservative

      expect(policy.max_attempts).to eq(2)
      expect(policy.base_interval).to eq(2.0)
      expect(policy.max_interval).to eq(60.0)
      expect(policy.backoff).to eq(:exponential)
      expect(policy.jitter).to eq(1.0)
    end
  end

  describe ".new" do
    it "creates custom policy" do
      policy = described_class.new(
        max_attempts: 10,
        base_interval: 0.1,
        max_interval: 5.0,
        backoff: :linear,
        jitter: 0.0,
        retryable_errors: [StandardError]
      )

      expect(policy.max_attempts).to eq(10)
      expect(policy.backoff).to eq(:linear)
      expect(policy.retryable_errors).to eq([StandardError])
    end

    it "is immutable" do
      policy = described_class.default
      expect(policy).to be_frozen
    end
  end

  describe "#multiplier" do
    it "returns exponential multiplier for exponential backoff" do
      policy = described_class.default
      expect(policy.multiplier).to eq(2.0)
    end

    it "returns linear multiplier for linear backoff" do
      policy = described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :linear,
        jitter: nil,
        retryable_errors: nil
      )
      expect(policy.multiplier).to eq(1.5)
    end

    it "returns constant multiplier for constant backoff" do
      policy = described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :constant,
        jitter: nil,
        retryable_errors: nil
      )
      expect(policy.multiplier).to eq(1.0)
    end
  end

  describe "#backoff_for" do
    let(:policy) do
      described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: nil,
        retryable_errors: nil
      )
    end

    it "calculates exponential backoff for attempt 0" do
      expect(policy.backoff_for(0)).to eq(1.0) # 1.0 * 2^0 = 1.0
    end

    it "calculates exponential backoff for attempt 1" do
      expect(policy.backoff_for(1)).to eq(2.0) # 1.0 * 2^1 = 2.0
    end

    it "calculates exponential backoff for attempt 2" do
      expect(policy.backoff_for(2)).to eq(4.0) # 1.0 * 2^2 = 4.0
    end

    it "caps at max_interval" do
      policy_with_low_max = described_class.new(
        max_attempts: 5,
        base_interval: 10.0,
        max_interval: 15.0,
        backoff: :exponential,
        jitter: nil,
        retryable_errors: nil
      )
      expect(policy_with_low_max.backoff_for(2)).to eq(15.0) # Capped
    end

    it "applies jitter when configured" do
      policy_with_jitter = described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: 0.5,
        retryable_errors: nil
      )

      # Jitter adds randomness, so interval should be between base and base + jitter
      10.times do
        interval = policy_with_jitter.backoff_for(0)
        expect(interval).to be_between(1.0, 1.5)
      end
    end
  end

  describe "#retriable?" do
    let(:policy) { described_class.default }

    it "returns true for timeout errors" do
      error = Faraday::TimeoutError.new
      expect(policy.retriable?(error)).to be true
    end

    it "returns true for connection failures" do
      error = Faraday::ConnectionFailed.new("connection refused")
      expect(policy.retriable?(error)).to be true
    end

    it "returns true for rate limit errors" do
      error = Smolagents::RateLimitError.new("rate limited")
      expect(policy.retriable?(error)).to be true
    end

    it "returns false for non-retriable errors" do
      error = Smolagents::AgentConfigurationError.new("bad config")
      expect(policy.retriable?(error)).to be false
    end

    it "uses custom retryable_errors when provided" do
      custom_policy = described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: nil,
        retryable_errors: [ArgumentError]
      )

      expect(custom_policy.retriable?(ArgumentError.new)).to be true
      expect(custom_policy.retriable?(RuntimeError.new)).to be false
    end

    it "uses default classification when retryable_errors is nil" do
      custom_policy = described_class.new(
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: nil,
        retryable_errors: nil
      )

      # Should fall back to RetryPolicyClassification
      expect(custom_policy.retriable?(Faraday::TimeoutError.new)).to be true
    end
  end

  describe "#attempts_remaining?" do
    let(:policy) do
      described_class.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :exponential, jitter: nil, retryable_errors: nil
      )
    end

    it "returns true when attempts remain" do
      expect(policy.attempts_remaining?(1)).to be true
      expect(policy.attempts_remaining?(2)).to be true
    end

    it "returns false when max attempts reached" do
      expect(policy.attempts_remaining?(3)).to be false
    end

    it "returns false when over max attempts" do
      expect(policy.attempts_remaining?(5)).to be false
    end
  end

  describe "#with" do
    let(:policy) { described_class.default }

    it "creates copy with modified attributes" do
      modified = policy.with(max_attempts: 10)

      expect(modified.max_attempts).to eq(10)
      expect(modified.base_interval).to eq(policy.base_interval)
      expect(modified.backoff).to eq(policy.backoff)
    end

    it "does not modify original" do
      modified = policy.with(max_attempts: 10)

      expect(policy.max_attempts).to eq(3)
      expect(modified.max_attempts).to eq(10)
    end

    it "supports multiple overrides" do
      modified = policy.with(
        max_attempts: 5,
        base_interval: 2.0,
        backoff: :linear
      )

      expect(modified.max_attempts).to eq(5)
      expect(modified.base_interval).to eq(2.0)
      expect(modified.backoff).to eq(:linear)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      policy = described_class.default

      case policy
      in { max_attempts:, backoff: :exponential }
        expect(max_attempts).to eq(3)
      else
        raise "Pattern should match"
      end
    end
  end
end
