require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::RateLimitExceeded do
  describe "error class" do
    it "is defined in RateLimiter module" do
      expect(described_class).to be_a(Class)
    end

    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::Errors::AgentError)
    end
  end

  describe "#initialize" do
    it "requires retry_after parameter" do
      error = described_class.new(retry_after: 1.5)
      expect(error.retry_after).to eq(1.5)
    end

    it "accepts optional tool_name" do
      error = described_class.new(retry_after: 1.0, tool_name: "search_tool")
      expect(error.tool_name).to eq("search_tool")
    end

    it "has nil tool_name by default" do
      error = described_class.new(retry_after: 1.0)
      expect(error.tool_name).to be_nil
    end
  end

  describe "#message" do
    it "includes rate limit exceeded text" do
      error = described_class.new(retry_after: 2.0)
      expect(error.message).to include("Rate limit exceeded")
    end

    it "includes retry_after value" do
      error = described_class.new(retry_after: 2.5)
      expect(error.message).to include("2.5")
    end

    it "rounds retry_after to 3 decimal places" do
      error = described_class.new(retry_after: 1.123456789)
      expect(error.message).to include("1.123")
    end
  end

  describe "#retry_after" do
    it "returns the retry wait time" do
      error = described_class.new(retry_after: 3.0)
      expect(error.retry_after).to eq(3.0)
    end

    it "handles float values" do
      error = described_class.new(retry_after: 0.5)
      expect(error.retry_after).to eq(0.5)
    end

    it "handles zero" do
      error = described_class.new(retry_after: 0.0)
      expect(error.retry_after).to eq(0.0)
    end
  end

  describe "#tool_name" do
    it "returns the tool name when set" do
      error = described_class.new(retry_after: 1.0, tool_name: "my_tool")
      expect(error.tool_name).to eq("my_tool")
    end
  end

  describe "raising and catching" do
    it "can be raised and caught" do
      expect do
        raise described_class.new(retry_after: 1.0)
      end.to raise_error(described_class)
    end

    it "can be caught as AgentError" do
      expect do
        raise described_class.new(retry_after: 1.0)
      end.to raise_error(Smolagents::Errors::AgentError)
    end

    it "can be caught as StandardError" do
      expect do
        raise described_class.new(retry_after: 1.0)
      end.to raise_error(StandardError)
    end

    it "preserves attributes when caught" do
      raise described_class.new(retry_after: 2.5, tool_name: "test")
    rescue described_class => e
      expect(e.retry_after).to eq(2.5)
      expect(e.tool_name).to eq("test")
    end
  end

  describe "attribute access" do
    it "allows accessing retry_after and tool_name" do
      error = described_class.new(retry_after: 1.5, tool_name: "search")

      expect(error.retry_after).to eq(1.5)
      expect(error.tool_name).to eq("search")
    end
  end
end
