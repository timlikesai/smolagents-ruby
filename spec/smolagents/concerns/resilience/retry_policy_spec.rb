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

      it "uses RetryPolicyClassification.retriable? for classification" do
        rate_limit = Smolagents::RateLimitError.new("rate limited")
        config_error = Smolagents::AgentConfigurationError.new("config")

        expect(policy.retriable?(rate_limit)).to be(true)
        expect(policy.retriable?(config_error)).to be(false)
      end
    end
  end
end

RSpec.describe Smolagents::Concerns::RetryPolicyClassification do
  describe ".retriable?" do
    it "returns true for rate limit errors" do
      error = Smolagents::RateLimitError.new("rate limited")
      expect(described_class.retriable?(error)).to be(true)
    end

    it "returns true for service unavailable errors" do
      error = Smolagents::ServiceUnavailableError.new("service down")
      expect(described_class.retriable?(error)).to be(true)
    end

    it "returns true for timeout errors" do
      error = Faraday::TimeoutError.new("timed out")
      expect(described_class.retriable?(error)).to be(true)
    end

    it "returns true for connection failed errors" do
      error = Faraday::ConnectionFailed.new("connection failed")
      expect(described_class.retriable?(error)).to be(true)
    end

    it "returns false for configuration errors" do
      error = Smolagents::AgentConfigurationError.new("bad config")
      expect(described_class.retriable?(error)).to be(false)
    end

    it "returns false for prompt injection errors" do
      error = Smolagents::PromptInjectionError.new("injection attempt")
      expect(described_class.retriable?(error)).to be(false)
    end

    it "returns false for MCP connection errors" do
      error = Smolagents::MCPConnectionError.new("mcp error")
      expect(described_class.retriable?(error)).to be(false)
    end

    context "with HTTP status codes" do
      it "returns true for 429 Too Many Requests" do
        error = instance_double(Smolagents::ApiError, status_code: 429)
        expect(described_class.retriable?(error)).to be(true)
      end

      it "returns true for 503 Service Unavailable" do
        error = instance_double(Smolagents::ApiError, status_code: 503)
        expect(described_class.retriable?(error)).to be(true)
      end

      it "returns true for 502 Bad Gateway" do
        error = instance_double(Smolagents::ApiError, status_code: 502)
        expect(described_class.retriable?(error)).to be(true)
      end

      it "returns true for 500 Internal Server Error" do
        error = instance_double(Smolagents::ApiError, status_code: 500)
        expect(described_class.retriable?(error)).to be(true)
      end

      it "returns false for 400 Bad Request" do
        error = instance_double(Smolagents::ApiError, status_code: 400)
        expect(described_class.retriable?(error)).to be(false)
      end

      it "returns false for 401 Unauthorized" do
        error = instance_double(Smolagents::ApiError, status_code: 401)
        expect(described_class.retriable?(error)).to be(false)
      end
    end

    it "returns false for unknown errors" do
      error = StandardError.new("something went wrong")
      expect(described_class.retriable?(error)).to be(false)
    end
  end

  describe "RETRIABLE_ERRORS" do
    it "includes transient network errors" do
      expect(described_class::RETRIABLE_ERRORS).to include(Faraday::TimeoutError)
      expect(described_class::RETRIABLE_ERRORS).to include(Faraday::ConnectionFailed)
    end

    it "includes rate limit error" do
      expect(described_class::RETRIABLE_ERRORS).to include(Smolagents::RateLimitError)
    end

    it "includes service unavailable error" do
      expect(described_class::RETRIABLE_ERRORS).to include(Smolagents::ServiceUnavailableError)
    end
  end

  describe "NON_RETRIABLE_ERRORS" do
    it "includes client errors" do
      expect(described_class::NON_RETRIABLE_ERRORS).to include(Faraday::ClientError)
    end

    it "includes configuration errors" do
      expect(described_class::NON_RETRIABLE_ERRORS).to include(Smolagents::AgentConfigurationError)
    end

    it "includes security errors" do
      expect(described_class::NON_RETRIABLE_ERRORS).to include(Smolagents::PromptInjectionError)
    end
  end

  describe "RETRIABLE_STATUS_CODES" do
    it "includes standard retriable HTTP codes" do
      codes = described_class::RETRIABLE_STATUS_CODES
      expect(codes).to include(408) # Request Timeout
      expect(codes).to include(429) # Too Many Requests
      expect(codes).to include(500) # Internal Server Error
      expect(codes).to include(502) # Bad Gateway
      expect(codes).to include(503) # Service Unavailable
      expect(codes).to include(504) # Gateway Timeout
    end
  end
end
