require "smolagents"

RSpec.describe Smolagents::Concerns::RetryPolicyClassification do
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

    it "includes MCP connection errors" do
      expect(described_class::NON_RETRIABLE_ERRORS).to include(Smolagents::MCPConnectionError)
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

  describe ".retriable_status?" do
    it "returns true for retriable status codes" do
      [408, 429, 500, 502, 503, 504].each do |code|
        expect(described_class.retriable_status?(code)).to be(true)
      end
    end

    it "returns false for non-retriable status codes" do
      [200, 201, 400, 401, 403, 404].each do |code|
        expect(described_class.retriable_status?(code)).to be(false)
      end
    end
  end

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to be_a(Hash)
      expect(methods.keys).to include(:retriable?, :retriable_status?)
    end
  end
end
