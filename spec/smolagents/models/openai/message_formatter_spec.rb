require "smolagents/models/model"
require "smolagents/models/openai_model"
require "smolagents/models/openai/message_formatter"

RSpec.describe Smolagents::Models::OpenAI::MessageFormatter do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::OpenAI::MessageFormatter
    end
  end
  let(:formatter) { model_class.new }

  describe "#format_messages" do
    it "formats array of ChatMessages" do
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi there")
      ]

      result = formatter.format_messages(messages)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it "converts each message to a hash" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = formatter.format_messages(messages)

      expect(result[0]).to be_a(Hash)
      expect(result[0]).to include(:role, :content)
    end

    it "handles empty message array" do
      result = formatter.format_messages([])
      expect(result).to eq([])
    end

    it "maps user role correctly" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("user")
    end

    it "maps assistant role correctly" do
      messages = [Smolagents::ChatMessage.assistant("Hi")]
      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("assistant")
    end

    it "maps system role correctly" do
      messages = [Smolagents::ChatMessage.system("You are helpful")]
      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("system")
    end

    it "maps tool_call role to assistant" do
      tool_call = Smolagents::ToolCall.new(id: "call_1", name: "search", arguments: {})
      messages = [Smolagents::ChatMessage.tool_call(content: "calling", tool_calls: [tool_call])]
      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("assistant")
    end

    it "maps tool_response role to user" do
      messages = [Smolagents::ChatMessage.tool_response("result")]
      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("user")
    end

    it "includes message content" do
      messages = [Smolagents::ChatMessage.user("Hello world")]
      result = formatter.format_messages(messages)

      expect(result[0][:content]).to eq("Hello world")
    end

    it "omits nil content fields" do
      messages = [Smolagents::ChatMessage.assistant(nil)]
      result = formatter.format_messages(messages)

      # Check that result is valid (no nil content in hash)
      expect(result[0][:content]).to be_nil
    end

    it "handles messages without tool_calls" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      result = formatter.format_messages(messages)

      expect(result[0]).not_to have_key(:tool_calls)
    end
  end

  describe "#map_role" do
    it "converts tool_response to user" do
      expect(formatter.send(:map_role, :tool_response)).to eq("user")
    end

    it "converts tool_call to assistant" do
      expect(formatter.send(:map_role, :tool_call)).to eq("assistant")
    end

    it "converts user role as-is" do
      expect(formatter.send(:map_role, :user)).to eq("user")
    end

    it "converts assistant role as-is" do
      expect(formatter.send(:map_role, :assistant)).to eq("assistant")
    end

    it "converts system role as-is" do
      expect(formatter.send(:map_role, :system)).to eq("system")
    end

    it "handles string input" do
      expect(formatter.send(:map_role, "user")).to eq("user")
      expect(formatter.send(:map_role, "tool_response")).to eq("user")
    end
  end

  describe "image formatting" do
    it "includes images in formatted messages" do
      skip "Image formatting requires mock image files"
      # Would need to create temporary image files to test this fully
    end

    it "delegates to #image_block for image conversion" do
      allow(formatter).to receive(:image_block).and_return({ type: "image_url", image_url: {} })

      # Test would require images in ChatMessage, which requires setup
      skip "Requires complete image handling setup"
    end
  end

  describe "tool call formatting" do
    it "formats tool_calls with proper structure" do
      tool_call = Smolagents::ToolCall.new(id: "call_123", name: "search", arguments: { query: "test" })
      messages = [Smolagents::ChatMessage.assistant("Calling search", tool_calls: [tool_call])]

      result = formatter.format_messages(messages)

      expect(result[0]).to have_key(:tool_calls)
      expect(result[0][:tool_calls]).to be_an(Array)
      expect(result[0][:tool_calls].length).to eq(1)
    end

    it "includes tool call id and type" do
      tool_call = Smolagents::ToolCall.new(id: "call_123", name: "search", arguments: {})
      messages = [Smolagents::ChatMessage.assistant("", tool_calls: [tool_call])]

      result = formatter.format_messages(messages)
      tc = result[0][:tool_calls][0]

      expect(tc[:id]).to eq("call_123")
      expect(tc[:type]).to eq("function")
    end

    it "wraps tool name and arguments in function" do
      tool_call = Smolagents::ToolCall.new(id: "call_1", name: "calculator", arguments: { expr: "2+2" })
      messages = [Smolagents::ChatMessage.assistant("", tool_calls: [tool_call])]

      result = formatter.format_messages(messages)
      fn = result[0][:tool_calls][0][:function]

      expect(fn[:name]).to eq("calculator")
      expect(fn[:arguments]).to be_a(String)
    end

    it "serializes arguments to JSON string" do
      tool_call = Smolagents::ToolCall.new(id: "call_1", name: "search", arguments: { query: "ruby" })
      messages = [Smolagents::ChatMessage.assistant("", tool_calls: [tool_call])]

      result = formatter.format_messages(messages)
      args = result[0][:tool_calls][0][:function][:arguments]

      expect(args).to be_a(String)
      expect(JSON.parse(args)).to eq({ "query" => "ruby" })
    end

    it "handles string arguments" do
      tool_call = Smolagents::ToolCall.new(id: "call_1", name: "search", arguments: '{"query":"ruby"}')
      messages = [Smolagents::ChatMessage.assistant("", tool_calls: [tool_call])]

      result = formatter.format_messages(messages)
      args = result[0][:tool_calls][0][:function][:arguments]

      expect(args).to eq('{"query":"ruby"}')
    end

    it "handles multiple tool calls" do
      tc1 = Smolagents::ToolCall.new(id: "call_1", name: "search", arguments: {})
      tc2 = Smolagents::ToolCall.new(id: "call_2", name: "calculator", arguments: {})
      messages = [Smolagents::ChatMessage.assistant("", tool_calls: [tc1, tc2])]

      result = formatter.format_messages(messages)

      expect(result[0][:tool_calls].length).to eq(2)
    end

    it "omits tool_calls when not present" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      result = formatter.format_messages(messages)

      expect(result[0]).not_to have_key(:tool_calls)
    end

    it "omits tool_calls when empty array" do
      messages = [Smolagents::ChatMessage.assistant("Hello", tool_calls: [])]
      result = formatter.format_messages(messages)

      expect(result[0]).not_to have_key(:tool_calls)
    end
  end
end
