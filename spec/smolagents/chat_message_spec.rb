# frozen_string_literal: true

RSpec.describe Smolagents::ChatMessage do
  describe ".system" do
    it "creates a system message" do
      msg = described_class.system("You are a helpful assistant")
      expect(msg.role).to eq(:system)
      expect(msg.content).to eq("You are a helpful assistant")
      expect(msg.tool_calls).to be_nil
    end
  end

  describe ".user" do
    it "creates a user message" do
      msg = described_class.user("Hello!")
      expect(msg.role).to eq(:user)
      expect(msg.content).to eq("Hello!")
    end
  end

  describe ".assistant" do
    it "creates an assistant message without tool calls" do
      msg = described_class.assistant("Here's the answer")
      expect(msg.role).to eq(:assistant)
      expect(msg.content).to eq("Here's the answer")
      expect(msg.tool_calls).to be_nil
    end

    it "creates an assistant message with tool calls" do
      tool_call = Smolagents::ToolCall.new(
        name: "search",
        arguments: { query: "test" },
        id: "call_1"
      )
      msg = described_class.assistant("Let me search", tool_calls: [tool_call])
      expect(msg.role).to eq(:assistant)
      expect(msg.tool_calls).to eq([tool_call])
    end
  end

  describe ".tool_call" do
    it "creates a tool call message" do
      tool_call = Smolagents::ToolCall.new(
        name: "search",
        arguments: { query: "test" },
        id: "call_1"
      )
      msg = described_class.tool_call([tool_call])
      expect(msg.role).to eq(:tool_call)
      expect(msg.tool_calls).to eq([tool_call])
    end
  end

  describe ".tool_response" do
    it "creates a tool response message" do
      msg = described_class.tool_response("Search results here", tool_call_id: "call_1")
      expect(msg.role).to eq(:tool_response)
      expect(msg.content).to eq("Search results here")
      expect(msg.raw[:tool_call_id]).to eq("call_1")
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      msg = described_class.user("Hello")
      expect(msg.to_h).to eq({
        role: :user,
        content: "Hello"
      })
    end

    it "includes tool calls if present" do
      tool_call = Smolagents::ToolCall.new(
        name: "search",
        arguments: { query: "test" },
        id: "call_1"
      )
      msg = described_class.assistant("Searching", tool_calls: [tool_call])
      hash = msg.to_h
      expect(hash[:tool_calls]).to be_an(Array)
      expect(hash[:tool_calls].first).to be_a(Hash)
    end
  end

  describe "#tool_calls?" do
    it "returns true when tool calls present" do
      tool_call = Smolagents::ToolCall.new(
        name: "search",
        arguments: {},
        id: "call_1"
      )
      msg = described_class.assistant("Searching", tool_calls: [tool_call])
      expect(msg.tool_calls?).to be true
    end

    it "returns false when no tool calls" do
      msg = described_class.user("Hello")
      expect(msg.tool_calls?).to be false
    end
  end
end
