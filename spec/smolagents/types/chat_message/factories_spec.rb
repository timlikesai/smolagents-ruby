require "spec_helper"

RSpec.describe Smolagents::Types::ChatMessageComponents::Factories do
  let(:chat_message) { Smolagents::Types::ChatMessage }
  let(:message_role) { Smolagents::Types::MessageRole }

  describe ".system" do
    it "creates a system message with content" do
      msg = chat_message.system("You are helpful")
      expect(msg.role).to eq(message_role::SYSTEM)
      expect(msg.content).to eq("You are helpful")
    end

    it "creates system message with keyword argument" do
      msg = chat_message.system(content: "Be concise")
      expect(msg.role).to eq(message_role::SYSTEM)
      expect(msg.content).to eq("Be concise")
    end

    it "has nil for optional fields" do
      msg = chat_message.system("System prompt")
      expect(msg.tool_calls).to be_nil
      expect(msg.images).to be_nil
      expect(msg.raw).to be_nil
      expect(msg.token_usage).to be_nil
    end
  end

  describe ".user" do
    it "creates a user message with content" do
      msg = chat_message.user("Hello")
      expect(msg.role).to eq(message_role::USER)
      expect(msg.content).to eq("Hello")
    end

    it "creates user message with keyword argument" do
      msg = chat_message.user(content: "Question?")
      expect(msg.role).to eq(message_role::USER)
      expect(msg.content).to eq("Question?")
    end

    it "defaults images to nil" do
      msg = chat_message.user("No images")
      expect(msg.images).to be_nil
    end

    it "accepts images parameter" do
      msg = chat_message.user("What's this?", images: ["photo.png"])
      expect(msg.images).to eq(["photo.png"])
    end

    it "accepts images with keyword content" do
      msg = chat_message.user(content: "Describe", images: ["a.jpg", "b.jpg"])
      expect(msg.content).to eq("Describe")
      expect(msg.images).to eq(["a.jpg", "b.jpg"])
    end
  end

  describe ".assistant" do
    it "creates an assistant message with content" do
      msg = chat_message.assistant("The answer is 42")
      expect(msg.role).to eq(message_role::ASSISTANT)
      expect(msg.content).to eq("The answer is 42")
    end

    it "accepts tool_calls parameter" do
      tool_call = Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1")
      msg = chat_message.assistant("Searching...", tool_calls: [tool_call])
      expect(msg.tool_calls).to eq([tool_call])
    end

    it "accepts raw parameter" do
      raw_response = { model: "gpt-4", finish_reason: "stop" }
      msg = chat_message.assistant("Response", raw: raw_response)
      expect(msg.raw).to eq(raw_response)
    end

    it "accepts token_usage parameter" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      msg = chat_message.assistant("Response", token_usage: usage)
      expect(msg.token_usage).to eq(usage)
    end

    it "accepts reasoning_content parameter" do
      msg = chat_message.assistant("Answer", reasoning_content: "Let me think...")
      expect(msg.reasoning_content).to eq("Let me think...")
    end

    it "accepts all optional parameters" do
      tool_call = Smolagents::Types::ToolCall.new(name: "calc", arguments: { x: 1 }, id: "c1")
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 5, output_tokens: 10)
      msg = chat_message.assistant(
        "Result",
        tool_calls: [tool_call],
        raw: { id: "msg_1" },
        token_usage: usage,
        reasoning_content: "Thinking"
      )
      expect(msg.content).to eq("Result")
      expect(msg.tool_calls).to eq([tool_call])
      expect(msg.raw).to eq({ id: "msg_1" })
      expect(msg.token_usage).to eq(usage)
      expect(msg.reasoning_content).to eq("Thinking")
    end

    it "allows nil content with tool calls" do
      tool_call = Smolagents::Types::ToolCall.new(name: "get_time", arguments: {}, id: "t1")
      msg = chat_message.assistant(nil, tool_calls: [tool_call])
      expect(msg.content).to be_nil
      expect(msg.tool_calls).to eq([tool_call])
    end
  end

  describe ".tool_call" do
    it "creates a tool_call message with tool_calls" do
      tool_call = Smolagents::Types::ToolCall.new(name: "search", arguments: { q: "ruby" }, id: "1")
      msg = chat_message.tool_call(tool_calls: [tool_call])
      expect(msg.role).to eq(message_role::TOOL_CALL)
      expect(msg.tool_calls).to eq([tool_call])
    end

    it "accepts tool_calls as positional argument" do
      tool_call = Smolagents::Types::ToolCall.new(name: "visit", arguments: {}, id: "2")
      msg = chat_message.tool_call([tool_call])
      expect(msg.tool_calls).to eq([tool_call])
    end

    it "handles multiple tool calls" do
      calls = [
        Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1"),
        Smolagents::Types::ToolCall.new(name: "visit", arguments: {}, id: "2")
      ]
      msg = chat_message.tool_call(calls)
      expect(msg.tool_calls.length).to eq(2)
    end
  end

  describe ".tool_response" do
    it "creates a tool_response message" do
      msg = chat_message.tool_response("Success: found 5 results")
      expect(msg.role).to eq(message_role::TOOL_RESPONSE)
      expect(msg.content).to eq("Success: found 5 results")
    end

    it "accepts tool_call_id parameter" do
      msg = chat_message.tool_response("Result", tool_call_id: "call_123")
      expect(msg.raw).to eq({ tool_call_id: "call_123" })
    end

    it "stores nil tool_call_id when not provided" do
      msg = chat_message.tool_response("Result")
      expect(msg.raw).to eq({ tool_call_id: nil })
    end
  end

  describe "ROLE_CONFIGS" do
    it "defines system, user, and tool_call configs" do
      configs = described_class::ROLE_CONFIGS
      expect(configs.keys).to contain_exactly(:system, :user, :tool_call)
    end

    it "is frozen" do
      expect(described_class::ROLE_CONFIGS).to be_frozen
    end
  end

  describe "metaprogrammed factory consistency" do
    it "all factory methods return ChatMessage instances" do
      tool_call = Smolagents::Types::ToolCall.new(name: "test", arguments: {}, id: "1")
      messages = [
        chat_message.system("prompt"),
        chat_message.user("question"),
        chat_message.assistant("answer"),
        chat_message.tool_call([tool_call]),
        chat_message.tool_response("result")
      ]
      messages.each do |msg|
        expect(msg).to be_a(chat_message)
      end
    end

    it "all messages are immutable" do
      messages = [
        chat_message.system("prompt"),
        chat_message.user("question"),
        chat_message.assistant("answer")
      ]
      messages.each do |msg|
        expect(msg).to be_frozen
      end
    end
  end
end
