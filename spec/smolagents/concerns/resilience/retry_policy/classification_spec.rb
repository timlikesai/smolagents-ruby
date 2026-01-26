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
end
