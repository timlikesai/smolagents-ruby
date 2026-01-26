require "spec_helper"
require "smolagents/concerns/formatting/messages"

RSpec.describe Smolagents::Concerns::MessageFormatting do
  let(:test_class) do
    Class.new { include Smolagents::Concerns::MessageFormatting }
  end
  let(:formatter) { test_class.new }

  describe "#format_single_message" do
    it "formats simple user message" do
      message = build_chat_message(role: :user, content: "Hello")
      result = formatter.format_single_message(message)

      expect(result).to eq({ role: "user", content: "Hello" })
    end

    it "formats system message" do
      message = build_chat_message(role: :system, content: "You are helpful")
      result = formatter.format_single_message(message)

      expect(result).to eq({ role: "system", content: "You are helpful" })
    end

    it "formats assistant message with tool calls" do
      tool_call = build_tool_call(id: "call_123", name: "search", arguments: { "query" => "test" })
      message = build_chat_message(role: :assistant, content: "Let me search", tool_calls: [tool_call])
      result = formatter.format_single_message(message)

      expect(result[:role]).to eq("assistant")
      expect(result[:content]).to eq("Let me search")
      expect(result[:tool_calls]).to be_an(Array)
      expect(result[:tool_calls].first[:function][:name]).to eq("search")
    end

    it "handles nil content" do
      message = build_chat_message(role: :assistant, content: nil)
      result = formatter.format_single_message(message)

      expect(result[:role]).to eq("assistant")
      expect(result[:content]).to be_nil
    end
  end

  describe "#format_messages_for_api" do
    it "formats multiple messages" do
      messages = [
        build_chat_message(role: :system, content: "Be helpful"),
        build_chat_message(role: :user, content: "Hello"),
        build_chat_message(role: :assistant, content: "Hi there!")
      ]

      result = formatter.format_messages_for_api(messages)

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result.map { |m| m[:role] }).to eq(%w[system user assistant])
    end

    it "handles empty message list" do
      result = formatter.format_messages_for_api([])
      expect(result).to eq([])
    end
  end

  describe "#format_tool_calls" do
    it "formats tool calls correctly" do
      tool_calls = [
        build_tool_call(id: "call_1", name: "search", arguments: { "query" => "test" }),
        build_tool_call(id: "call_2", name: "calculate", arguments: { "expr" => "2+2" })
      ]

      result = formatter.format_tool_calls(tool_calls)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first[:id]).to eq("call_1")
      expect(result.first[:type]).to eq("function")
      expect(result.first[:function][:name]).to eq("search")
    end

    it "converts hash arguments to JSON string" do
      tool_call = build_tool_call(id: "call_1", name: "search", arguments: { "query" => "test", "limit" => 10 })

      result = formatter.format_tool_calls([tool_call])
      arguments = result.first[:function][:arguments]

      expect(arguments).to be_a(String)
      parsed = JSON.parse(arguments)
      expect(parsed).to eq({ "query" => "test", "limit" => 10 })
    end

    it "keeps string arguments as-is" do
      tool_call = build_tool_call(id: "call_1", name: "search", arguments: '{"query":"test"}')

      result = formatter.format_tool_calls([tool_call])
      expect(result.first[:function][:arguments]).to eq('{"query":"test"}')
    end
  end

  describe "#inject_before_last_user" do
    let(:system_msg) { Smolagents::Types::ChatMessage.system("System prompt") }
    let(:user_msg) { Smolagents::Types::ChatMessage.user("Hello") }
    let(:assistant_msg) { Smolagents::Types::ChatMessage.assistant("Hi there") }
    let(:context_msg) { Smolagents::Types::ChatMessage.system("[CONTEXT] Step 1") }

    context "with messages ending in user message" do
      let(:messages) { [system_msg, user_msg] }

      it "injects before the last user message" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(3)
        expect(result[0]).to eq(system_msg)
        expect(result[1]).to eq(context_msg)
        expect(result[2]).to eq(user_msg)
      end

      it "does not modify original array" do
        original_size = messages.size
        formatter.inject_before_last_user(messages, context_msg)
        expect(messages.size).to eq(original_size)
      end
    end

    context "with multiple user messages" do
      let(:user_msg2) { Smolagents::Types::ChatMessage.user("Follow-up") }
      let(:messages) { [system_msg, user_msg, assistant_msg, user_msg2] }

      it "injects before the LAST user message only" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(5)
        expect(result[3]).to eq(context_msg)
        expect(result[4]).to eq(user_msg2)
      end
    end

    context "with no user messages" do
      let(:messages) { [system_msg, assistant_msg] }

      it "appends to end" do
        result = formatter.inject_before_last_user(messages, context_msg)
        expect(result.size).to eq(3)
        expect(result.last).to eq(context_msg)
      end
    end

    context "with empty messages" do
      it "returns array with just the injected message" do
        result = formatter.inject_before_last_user([], context_msg)
        expect(result).to eq([context_msg])
      end
    end
  end

  describe "#parse_api_response" do
    it "raises NotImplementedError by default" do
      expect do
        formatter.parse_api_response({})
      end.to raise_error(NotImplementedError, /parse_api_response must be implemented/)
    end
  end

  describe "integration with models" do
    it "can be included in a model class" do
      model_class = Class.new do
        include Smolagents::Concerns::MessageFormatting

        def generate(messages) = format_messages_for_api(messages)
      end

      model = model_class.new
      messages = [build_chat_message(role: :user, content: "Test")]
      result = model.generate(messages)

      expect(result).to be_an(Array)
      expect(result.first[:role]).to eq("user")
    end
  end
end
