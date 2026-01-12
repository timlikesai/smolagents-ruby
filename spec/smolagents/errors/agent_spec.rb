# frozen_string_literal: true

RSpec.describe "Agent Errors" do
  describe Smolagents::AgentError do
    it "inherits from StandardError" do
      expect(described_class.superclass).to eq(StandardError)
    end

    it "can be raised with a message" do
      expect { raise described_class, "test error" }.to raise_error(described_class, "test error")
    end
  end

  describe Smolagents::AgentExecutionError do
    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::AgentError)
    end
  end

  describe Smolagents::AgentGenerationError do
    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::AgentError)
    end
  end

  describe Smolagents::AgentParsingError do
    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::AgentError)
    end
  end

  describe Smolagents::AgentMaxStepsError do
    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::AgentError)
    end
  end

  describe Smolagents::AgentToolCallError do
    it "inherits from AgentExecutionError" do
      expect(described_class.superclass).to eq(Smolagents::AgentExecutionError)
    end
  end

  describe Smolagents::AgentToolExecutionError do
    it "inherits from AgentExecutionError" do
      expect(described_class.superclass).to eq(Smolagents::AgentExecutionError)
    end
  end
end
