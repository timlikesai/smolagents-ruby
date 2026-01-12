RSpec.describe Smolagents::Concerns::MessageFormatting do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::MessageFormatting
    end
  end

  let(:instance) { test_class.new }

  describe "#format_single_message" do
    it "formats simple user message" do
      message = Smolagents::ChatMessage.user("Hello")
      result = instance.format_single_message(message)

      expect(result).to eq({ role: "user", content: "Hello" })
    end

    it "formats system message" do
      message = Smolagents::ChatMessage.system("You are helpful")
      result = instance.format_single_message(message)

      expect(result).to eq({ role: "system", content: "You are helpful" })
    end

    it "formats assistant message with tool calls" do
      tool_call = Smolagents::ToolCall.new(
        id: "call_123",
        name: "search",
        arguments: { "query" => "test" }
      )
      message = Smolagents::ChatMessage.assistant("Let me search", tool_calls: [tool_call])
      result = instance.format_single_message(message)

      expect(result[:role]).to eq("assistant")
      expect(result[:content]).to eq("Let me search")
      expect(result[:tool_calls]).to be_an(Array)
      expect(result[:tool_calls].first[:function][:name]).to eq("search")
    end

    it "handles nil content" do
      message = Smolagents::ChatMessage.new(
        role: :assistant,
        content: nil,
        tool_calls: nil,
        raw: nil,
        token_usage: nil,
        images: nil
      )
      result = instance.format_single_message(message)

      expect(result[:role]).to eq("assistant")
      expect(result[:content]).to be_nil
    end
  end

  describe "#format_messages_for_api" do
    it "formats multiple messages" do
      messages = [
        Smolagents::ChatMessage.system("Be helpful"),
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi there!")
      ]

      result = instance.format_messages_for_api(messages)

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result.map { |m| m[:role] }).to eq(%w[system user assistant])
    end

    it "handles empty message list" do
      result = instance.format_messages_for_api([])
      expect(result).to eq([])
    end
  end

  describe "#format_tool_calls" do
    it "formats tool calls correctly" do
      tool_calls = [
        Smolagents::ToolCall.new(id: "call_1", name: "search", arguments: { "query" => "test" }),
        Smolagents::ToolCall.new(id: "call_2", name: "calculate", arguments: { "expr" => "2+2" })
      ]

      result = instance.format_tool_calls(tool_calls)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first[:id]).to eq("call_1")
      expect(result.first[:type]).to eq("function")
      expect(result.first[:function][:name]).to eq("search")
    end

    it "converts hash arguments to JSON string" do
      tool_call = Smolagents::ToolCall.new(
        id: "call_1",
        name: "search",
        arguments: { "query" => "test", "limit" => 10 }
      )

      result = instance.format_tool_calls([tool_call])
      arguments = result.first[:function][:arguments]

      expect(arguments).to be_a(String)
      parsed = JSON.parse(arguments)
      expect(parsed).to eq({ "query" => "test", "limit" => 10 })
    end

    it "keeps string arguments as-is" do
      tool_call = Smolagents::ToolCall.new(
        id: "call_1",
        name: "search",
        arguments: '{"query":"test"}'
      )

      result = instance.format_tool_calls([tool_call])
      expect(result.first[:function][:arguments]).to eq('{"query":"test"}')
    end
  end

  describe "#format_tools_for_api" do
    it "formats tools correctly" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = {
          query: { type: "string", description: "Search query" },
          limit: { type: "integer", description: "Result limit", nullable: true }
        }
        self.output_type = "string"
      end.new

      result = instance.format_tools_for_api([search_tool])

      expect(result).to be_an(Array)
      expect(result.first[:type]).to eq("function")
      expect(result.first[:function][:name]).to eq("search")
      expect(result.first[:function][:description]).to eq("Search for information")
      expect(result.first[:function][:parameters][:type]).to eq("object")
      expect(result.first[:function][:parameters][:properties]).to have_key(:query)
      expect(result.first[:function][:parameters][:required]).to eq([:query])
    end

    it "excludes nullable parameters from required list" do
      tool = Class.new(Smolagents::Tool) do
        self.tool_name = "test"
        self.description = "Test"
        self.inputs = {
          required_param: { type: "string", description: "Required" },
          optional_param: { type: "string", description: "Optional", nullable: true }
        }
        self.output_type = "string"
      end.new

      result = instance.format_tools_for_api([tool])
      expect(result.first[:function][:parameters][:required]).to eq([:required_param])
    end

    it "handles empty tools list" do
      result = instance.format_tools_for_api([])
      expect(result).to eq([])
    end
  end

  describe "#parse_api_response" do
    it "raises NotImplementedError by default" do
      expect do
        instance.parse_api_response({})
      end.to raise_error(NotImplementedError, /parse_api_response must be implemented/)
    end
  end

  describe "integration with models" do
    it "can be included in a model class" do
      model_class = Class.new do
        include Smolagents::Concerns::MessageFormatting

        def generate(messages)
          format_messages_for_api(messages)
        end
      end

      model = model_class.new
      messages = [Smolagents::ChatMessage.user("Test")]
      result = model.generate(messages)

      expect(result).to be_an(Array)
      expect(result.first[:role]).to eq("user")
    end
  end
end
