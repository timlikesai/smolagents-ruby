require "smolagents/models/model"

RSpec.describe Smolagents::Models::Model::ToolParsing do
  let(:model) { Smolagents::Model.new(model_id: "test-model") }

  describe "#parse_tool_calls" do
    context "with raw tool call data" do
      it "returns the input unchanged" do
        tool_calls = [
          { id: "call_123", type: "function", function: { name: "search", arguments: '{"query":"test"}' } }
        ]

        result = model.parse_tool_calls(tool_calls)
        expect(result).to eq(tool_calls)
      end
    end

    context "with Hash message" do
      it "returns the hash unchanged" do
        message = { type: "tool_use", id: "tool_123", name: "search", input: { query: "test" } }

        result = model.parse_tool_calls(message)
        expect(result).to eq(message)
      end
    end

    context "with Array of tool calls" do
      it "returns the array unchanged" do
        message = [
          { type: "tool_use", id: "tool_1", name: "search", input: {} },
          { type: "tool_use", id: "tool_2", name: "calculator", input: {} }
        ]

        result = model.parse_tool_calls(message)
        expect(result).to eq(message)
      end
    end

    context "with nil" do
      it "returns nil unchanged" do
        result = model.parse_tool_calls(nil)
        expect(result).to be_nil
      end
    end

    context "with empty array" do
      it "returns empty array unchanged" do
        result = model.parse_tool_calls([])
        expect(result).to eq([])
      end
    end

    context "with string" do
      it "returns the string unchanged" do
        message = "raw tool call string"

        result = model.parse_tool_calls(message)
        expect(result).to eq(message)
      end
    end

    context "default implementation" do
      it "provides pass-through for subclass override" do
        # Demonstrates that subclasses can override to handle provider-specific formats
        openai_format = [
          { id: "call_123", type: "function", function: { name: "search", arguments: '{"query":"ruby"}' } }
        ]
        anthropic_format = [
          { type: "tool_use", id: "tool_123", name: "search", input: { query: "ruby" } }
        ]

        # Base implementation just passes through
        expect(model.parse_tool_calls(openai_format)).to eq(openai_format)
        expect(model.parse_tool_calls(anthropic_format)).to eq(anthropic_format)
      end
    end
  end
end
