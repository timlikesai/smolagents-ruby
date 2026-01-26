require "smolagents"

RSpec.describe Smolagents::Concerns::RetryPolicy do
  describe ".default" do
    it "returns a policy with sensible defaults" do
      policy = described_class.default
      expect(policy.max_attempts).to eq(3)
      expect(policy.base_interval).to eq(1.0)
      expect(policy.max_interval).to eq(30.0)
      expect(policy.backoff).to eq(:exponential)
      expect(policy.jitter).to eq(0.5)
    end

    it "includes retriable errors" do
      policy = described_class.default
      expect(policy.retryable_errors).to include(Smolagents::RateLimitError)
      expect(policy.retryable_errors).to include(Smolagents::ServiceUnavailableError)
    end
  end

  describe ".aggressive" do
    it "has more attempts and shorter intervals" do
      policy = described_class.aggressive
      expect(policy.max_attempts).to eq(5)
      expect(policy.base_interval).to eq(0.5)
      expect(policy.max_interval).to eq(15.0)
      expect(policy.jitter).to eq(0.3)
    end
  end

  describe ".conservative" do
    it "has fewer attempts and longer intervals" do
      policy = described_class.conservative
      expect(policy.max_attempts).to eq(2)
      expect(policy.base_interval).to eq(2.0)
      expect(policy.max_interval).to eq(60.0)
      expect(policy.jitter).to eq(1.0)
    end
  end

  describe "#multiplier" do
    it "returns 2.0 for exponential backoff" do
      policy = described_class.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :exponential, jitter: 0.0, retryable_errors: []
      )
      expect(policy.multiplier).to eq(2.0)
    end

    it "returns 1.5 for linear backoff" do
      policy = described_class.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :linear, jitter: 0.0, retryable_errors: []
      )
      expect(policy.multiplier).to eq(1.5)
    end

    it "returns 1.0 for constant backoff" do
      policy = described_class.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :constant, jitter: 0.0, retryable_errors: []
      )
      expect(policy.multiplier).to eq(1.0)
    end
  end

  describe "#backoff_for" do
    context "with exponential backoff" do
      let(:policy) do
        described_class.new(
          max_attempts: 5, base_interval: 1.0, max_interval: 30.0,
          backoff: :exponential, jitter: 0.0, retryable_errors: []
        )
      end

      it "doubles each interval" do
        expect(policy.backoff_for(0)).to eq(1.0)  # 1.0 * 2^0
        expect(policy.backoff_for(1)).to eq(2.0)  # 1.0 * 2^1
        expect(policy.backoff_for(2)).to eq(4.0)  # 1.0 * 2^2
        expect(policy.backoff_for(3)).to eq(8.0)  # 1.0 * 2^3
      end

      it "caps at max_interval" do
        expect(policy.backoff_for(10)).to eq(30.0)
      end
    end

    context "with jitter" do
      let(:policy) do
        described_class.new(
          max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
          backoff: :exponential, jitter: 0.5, retryable_errors: []
        )
      end

      it "adds randomness within jitter range" do
        results = Array.new(10) { policy.backoff_for(0) }
        expect(results.min).to be >= 1.0
        expect(results.max).to be <= 1.5
        expect(results.uniq.size).to be > 1 # Should have variation
      end

      it "includes base interval plus jitter" do
        # For retry 0 with base 1.0 and jitter 0.5, expect 1.0-1.5
        result = policy.backoff_for(0)
        expect(result).to be >= 1.0
        expect(result).to be <= 1.5
      end
    end
  end

  describe "#retriable?" do
    let(:policy) do
      described_class.new(
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :exponential, jitter: 0.0,
        retryable_errors: [Smolagents::RateLimitError]
      )
    end

    it "returns true for configured error types" do
      error = Smolagents::RateLimitError.new("rate limited")
      expect(policy.retriable?(error)).to be(true)
    end

    it "returns false for non-configured error types" do
      error = Smolagents::AgentConfigurationError.new("config error")
      expect(policy.retriable?(error)).to be(false)
    end

    context "when retryable_errors is nil" do
      let(:policy) do
        described_class.new(
          max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
          backoff: :exponential, jitter: 0.0, retryable_errors: nil
        )
      end

      it "uses default retriable errors for classification" do
        rate_limit = Smolagents::RateLimitError.new("rate limited")
        config_error = Smolagents::AgentConfigurationError.new("config")

        expect(policy.retriable?(rate_limit)).to be(true)
        expect(policy.retriable?(config_error)).to be(false)
      end
    end
  end

  describe "#attempts_remaining?" do
    let(:policy) { described_class.default }

    it "returns true when current attempt is less than max" do
      expect(policy.attempts_remaining?(1)).to be(true)
      expect(policy.attempts_remaining?(2)).to be(true)
    end

    it "returns false when current attempt equals or exceeds max" do
      expect(policy.attempts_remaining?(3)).to be(false)
      expect(policy.attempts_remaining?(4)).to be(false)
    end
  end

  describe "#with" do
    it "creates new policy with overridden values" do
      original = described_class.default
      modified = original.with(max_attempts: 10)

      expect(modified.max_attempts).to eq(10)
      expect(modified.base_interval).to eq(original.base_interval)
      expect(original.max_attempts).to eq(3) # Original unchanged
    end
  end
end
