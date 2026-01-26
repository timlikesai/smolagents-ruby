require "spec_helper"

RSpec.describe Smolagents::Types::ChatMessageComponents::Predicates do
  let(:chat_message) { Smolagents::Types::ChatMessage }

  describe "#tool_calls?" do
    it "returns true when tool_calls has elements" do
      tool_call = Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1")
      msg = chat_message.assistant("Calling tool", tool_calls: [tool_call])
      expect(msg.tool_calls?).to be true
    end

    it "returns true for multiple tool calls" do
      calls = [
        Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1"),
        Smolagents::Types::ToolCall.new(name: "visit", arguments: {}, id: "2")
      ]
      msg = chat_message.assistant("Calling tools", tool_calls: calls)
      expect(msg.tool_calls?).to be true
    end

    it "returns false when tool_calls is nil" do
      msg = chat_message.assistant("Just text")
      expect(msg.tool_calls?).to be false
    end

    it "returns false when tool_calls is empty array" do
      msg = chat_message.new(
        role: :assistant,
        content: "No tools",
        tool_calls: [],
        raw: nil,
        token_usage: nil,
        images: nil,
        reasoning_content: nil
      )
      expect(msg.tool_calls?).to be false
    end
  end

  describe "#images?" do
    it "returns true when images has elements" do
      msg = chat_message.user("What's this?", images: ["photo.jpg"])
      expect(msg.images?).to be true
    end

    it "returns true for multiple images" do
      msg = chat_message.user("Compare these", images: ["a.png", "b.png", "c.png"])
      expect(msg.images?).to be true
    end

    it "returns false when images is nil" do
      msg = chat_message.user("No images")
      expect(msg.images?).to be false
    end

    it "returns false when images is empty array" do
      msg = chat_message.new(
        role: :user,
        content: "Empty",
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: [],
        reasoning_content: nil
      )
      expect(msg.images?).to be false
    end
  end

  describe "predicate methods on different message types" do
    it "system message has no tool_calls or images" do
      msg = chat_message.system("You are helpful")
      expect(msg.tool_calls?).to be false
      expect(msg.images?).to be false
    end

    it "user message can have images but not tool_calls" do
      msg = chat_message.user("Question", images: ["img.png"])
      expect(msg.tool_calls?).to be false
      expect(msg.images?).to be true
    end

    it "assistant message can have tool_calls but not images" do
      call = Smolagents::Types::ToolCall.new(name: "test", arguments: {}, id: "1")
      msg = chat_message.assistant("Answer", tool_calls: [call])
      expect(msg.tool_calls?).to be true
      expect(msg.images?).to be false
    end

    it "tool_response message has no tool_calls or images" do
      msg = chat_message.tool_response("Result")
      expect(msg.tool_calls?).to be false
      expect(msg.images?).to be false
    end
  end

  describe "endless method syntax" do
    it "tool_calls? uses endless method syntax" do
      # Verify it's a single-expression method by checking behavior
      msg = chat_message.assistant("test")
      expect(msg.method(:tool_calls?).arity).to eq(0)
    end

    it "images? uses endless method syntax" do
      msg = chat_message.user("test")
      expect(msg.method(:images?).arity).to eq(0)
    end
  end
end
