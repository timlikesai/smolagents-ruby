# frozen_string_literal: true

RSpec.describe Smolagents::Persistence do
  describe Smolagents::Persistence::Error do
    it "inherits from AgentError" do
      expect(described_class.superclass).to eq(Smolagents::AgentError)
    end
  end

  describe Smolagents::Persistence::MissingModelError do
    it "includes expected class in message" do
      error = described_class.new("Smolagents::OpenAIModel")

      expect(error.message).to include("Model required")
      expect(error.message).to include("Smolagents::OpenAIModel")
    end

    it "supports pattern matching" do
      error = described_class.new("Smolagents::OpenAIModel")

      case error
      in Smolagents::Persistence::MissingModelError[expected_class:]
        expect(expected_class).to eq("Smolagents::OpenAIModel")
      end
    end
  end

  describe Smolagents::Persistence::UnknownToolError do
    it "includes tool name and available tools" do
      error = described_class.new("unknown_tool")

      expect(error.message).to include("unknown_tool")
      expect(error.message).to include("not in registry")
      expect(error.tool_name).to eq("unknown_tool")
      expect(error.available_tools).to be_an(Array)
    end

    it "supports pattern matching" do
      error = described_class.new("missing_tool")

      case error
      in Smolagents::Persistence::UnknownToolError[tool_name:, available_tools:]
        expect(tool_name).to eq("missing_tool")
        expect(available_tools).to include("final_answer")
      end
    end
  end

  describe Smolagents::Persistence::InvalidManifestError do
    it "aggregates validation errors" do
      error = described_class.new(["missing version", "missing model"])

      expect(error.message).to include("missing version")
      expect(error.message).to include("missing model")
      expect(error.validation_errors).to eq(["missing version", "missing model"])
    end

    it "handles single error" do
      error = described_class.new("single error")

      expect(error.validation_errors).to eq(["single error"])
    end
  end

  describe Smolagents::Persistence::VersionMismatchError do
    it "includes version information" do
      error = described_class.new("2.0", "1.0")

      expect(error.message).to include("2.0")
      expect(error.message).to include("not supported")
      expect(error.got_version).to eq("2.0")
      expect(error.expected_version).to eq("1.0")
    end
  end

  describe Smolagents::Persistence::UnserializableToolError do
    it "includes tool information" do
      error = described_class.new("custom_tool", "CustomTool")

      expect(error.message).to include("custom_tool")
      expect(error.message).to include("CustomTool")
      expect(error.message).to include("cannot be serialized")
    end
  end
end
