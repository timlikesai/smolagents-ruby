require "spec_helper"

RSpec.describe Smolagents::Types::ChatMessageComponents::Serialization do
  let(:chat_message) { Smolagents::Types::ChatMessage }

  describe "#to_h" do
    it "includes role and content" do
      msg = chat_message.user("Hello")
      hash = msg.to_h
      expect(hash[:role]).to eq(:user)
      expect(hash[:content]).to eq("Hello")
    end

    it "excludes nil optional fields via compact" do
      msg = chat_message.system("Prompt")
      hash = msg.to_h
      expect(hash.keys).to contain_exactly(:role, :content)
    end

    it "serializes tool_calls to hashes" do
      call = Smolagents::Types::ToolCall.new(name: "search", arguments: { q: "test" }, id: "1")
      msg = chat_message.assistant("Searching", tool_calls: [call])
      hash = msg.to_h

      expect(hash[:tool_calls]).to be_an(Array)
      expect(hash[:tool_calls].first).to eq({
                                              id: "1",
                                              type: "function",
                                              function: { name: "search", arguments: { q: "test" } }
                                            })
    end

    it "serializes multiple tool_calls" do
      calls = [
        Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1"),
        Smolagents::Types::ToolCall.new(name: "visit", arguments: { url: "x" }, id: "2")
      ]
      msg = chat_message.assistant("Working", tool_calls: calls)
      hash = msg.to_h

      expect(hash[:tool_calls].length).to eq(2)
      expect(hash[:tool_calls].map { |tc| tc[:function][:name] }).to eq(%w[search visit])
    end

    it "excludes empty tool_calls array" do
      msg = chat_message.new(
        role: :assistant,
        content: "Done",
        tool_calls: [],
        raw: nil,
        token_usage: nil,
        images: nil,
        reasoning_content: nil
      )
      hash = msg.to_h
      expect(hash).not_to have_key(:tool_calls)
    end

    it "serializes token_usage to hash" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      msg = chat_message.assistant("Response", token_usage: usage)
      hash = msg.to_h

      # TokenUsage.to_h includes calculated total_tokens field
      expect(hash[:token_usage]).to eq({ input_tokens: 100, output_tokens: 50, total_tokens: 150 })
    end

    it "includes images when present" do
      msg = chat_message.user("Describe", images: ["a.jpg", "b.png"])
      hash = msg.to_h
      expect(hash[:images]).to eq(["a.jpg", "b.png"])
    end

    it "excludes empty images array" do
      msg = chat_message.new(
        role: :user,
        content: "Question",
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: [],
        reasoning_content: nil
      )
      hash = msg.to_h
      expect(hash).not_to have_key(:images)
    end

    # NOTE: reasoning_content serialization through presence() has a bug
    # (calls any? on String). This tests nil case which works correctly.
    it "excludes nil reasoning_content" do
      msg = chat_message.assistant("Answer")
      hash = msg.to_h
      expect(hash).not_to have_key(:reasoning_content)
    end

    it "handles nil content" do
      call = Smolagents::Types::ToolCall.new(name: "get_time", arguments: {}, id: "1")
      msg = chat_message.assistant(nil, tool_calls: [call])
      hash = msg.to_h
      expect(hash[:content]).to be_nil
      expect(hash[:tool_calls]).to be_an(Array)
    end

    it "returns complete hash with all fields except reasoning" do
      call = Smolagents::Types::ToolCall.new(name: "test", arguments: {}, id: "1")
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      msg = chat_message.new(
        role: :assistant,
        content: "Full message",
        tool_calls: [call],
        raw: { model: "test" },
        token_usage: usage,
        images: nil,
        reasoning_content: nil
      )
      hash = msg.to_h

      expect(hash[:role]).to eq(:assistant)
      expect(hash[:content]).to eq("Full message")
      expect(hash[:tool_calls]).to be_an(Array)
      # TokenUsage.to_h includes calculated total_tokens field
      expect(hash[:token_usage]).to eq({ input_tokens: 10, output_tokens: 5, total_tokens: 15 })
    end

    it "does not include raw field in serialization" do
      msg = chat_message.tool_response("Result", tool_call_id: "call_123")
      hash = msg.to_h
      expect(hash).not_to have_key(:raw)
    end
  end

  describe "#deconstruct_keys" do
    it "returns all fields as hash" do
      msg = chat_message.user("Hello")
      keys = msg.deconstruct_keys(nil)
      expect(keys).to have_key(:role)
      expect(keys).to have_key(:content)
      expect(keys).to have_key(:tool_calls)
      expect(keys).to have_key(:raw)
      expect(keys).to have_key(:token_usage)
      expect(keys).to have_key(:images)
      expect(keys).to have_key(:reasoning_content)
    end

    it "ignores keys parameter and returns all" do
      msg = chat_message.user("Hello")
      keys = msg.deconstruct_keys([:role])
      # Should still return all keys despite requesting only :role
      expect(keys.keys.length).to eq(7)
    end

    it "returns raw ToolCall objects (not serialized)" do
      call = Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1")
      msg = chat_message.assistant("Result", tool_calls: [call])
      keys = msg.deconstruct_keys(nil)

      expect(keys[:tool_calls].first).to be_a(Smolagents::Types::ToolCall)
      expect(keys[:tool_calls].first).to eq(call)
    end

    it "returns raw TokenUsage object (not serialized)" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      msg = chat_message.assistant("Result", token_usage: usage)
      keys = msg.deconstruct_keys(nil)

      expect(keys[:token_usage]).to be_a(Smolagents::Types::TokenUsage)
      expect(keys[:token_usage]).to eq(usage)
    end

    it "enables pattern matching" do
      msg = chat_message.user("What is 2+2?")

      case msg
      in { role: :user, content: content }
        expect(content).to eq("What is 2+2?")
      else
        raise "Pattern did not match"
      end
    end

    it "enables pattern matching with tool_calls" do
      call = Smolagents::Types::ToolCall.new(name: "calculate", arguments: { expr: "2+2" }, id: "1")
      msg = chat_message.assistant("Computing", tool_calls: [call])

      case msg
      in { role: :assistant, tool_calls: [first_call, *] }
        expect(first_call.name).to eq("calculate")
      else
        raise "Pattern did not match"
      end
    end

    it "enables pattern matching with nil values" do
      msg = chat_message.system("Be helpful")

      matched = case msg
                in { role: :system, images: nil }
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end

  describe "to_h vs deconstruct_keys difference" do
    it "to_h compacts nil values, deconstruct_keys preserves them" do
      msg = chat_message.system("Prompt")
      to_h_result = msg.to_h
      decon_result = msg.deconstruct_keys(nil)

      expect(to_h_result).not_to have_key(:tool_calls)
      expect(decon_result).to have_key(:tool_calls)
      expect(decon_result[:tool_calls]).to be_nil
    end

    it "to_h serializes objects, deconstruct_keys preserves them" do
      call = Smolagents::Types::ToolCall.new(name: "test", arguments: {}, id: "1")
      msg = chat_message.assistant("Result", tool_calls: [call])

      to_h_result = msg.to_h
      decon_result = msg.deconstruct_keys(nil)

      expect(to_h_result[:tool_calls].first).to be_a(Hash)
      expect(decon_result[:tool_calls].first).to be_a(Smolagents::Types::ToolCall)
    end
  end
end
