require "smolagents/models/model"
require "smolagents/models/anthropic_model"
require "smolagents/models/anthropic/request_builder"
require "smolagents/models/anthropic/message_formatter"

RSpec.describe Smolagents::Models::Anthropic::RequestBuilder do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::Anthropic::MessageFormatter
      include Smolagents::Models::Anthropic::RequestBuilder

      attr_reader :model_id

      def initialize
        @api_key = "test-api-key"
        @temperature = 0.7
        @max_tokens = 1024
        @model_id = "claude-3-sonnet-20240229"
      end
    end
  end
  let(:builder) { model_class.new }

  describe "#build_client" do
    it "creates an Anthropic::Client" do
      skip "Anthropic gem not loaded" unless defined?(Anthropic)

      client = builder.build_client

      expect(client).to be_a(Anthropic::Client)
    end

    it "uses api_key for authentication" do
      skip "Anthropic gem not loaded" unless defined?(Anthropic)

      client = builder.build_client

      expect(client).not_to be_nil
    end
  end

  describe "#build_params" do
    before do
      allow(builder).to receive_messages(format_messages: [{ role: "user", content: "Hello" }], format_tools: [])
    end

    it "returns a hash of parameters" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(messages, nil, 0.7, 200, nil)

      expect(result).to be_a(Hash)
    end

    it "extracts system message from messages" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      allow(builder).to receive(:format_messages).and_call_original

      result = builder.build_params(messages, nil, 0.7, 200, nil)

      expect(result).to have_key(:system)
    end

    it "removes system messages from user messages" do
      messages = [
        Smolagents::ChatMessage.system("System"),
        Smolagents::ChatMessage.user("Hello")
      ]

      allow(builder).to receive(:format_messages) do |msgs|
        msgs.map { |m| { role: m.role.to_s, content: m.content } }
      end

      result = builder.build_params(messages, nil, 0.7, 200, nil)

      # After extraction, only user message should be formatted
      expect(result[:messages].length).to eq(1)
    end

    it "includes temperature parameter" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(messages, nil, 0.5, 200, nil)

      expect(result).to have_key(:temperature)
      expect(result[:temperature]).to eq(0.5)
    end

    it "includes max_tokens parameter" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(messages, nil, 0.7, 500, nil)

      expect(result).to have_key(:max_tokens)
      expect(result[:max_tokens]).to eq(500)
    end

    it "includes stop_sequences parameter" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      stop_seqs = %w[STOP END]

      result = builder.build_params(messages, stop_seqs, 0.7, 200, nil)

      expect(result).to have_key(:stop_sequences)
      expect(result[:stop_sequences]).to eq(stop_seqs)
    end

    it "handles nil system content" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_params(messages, nil, 0.7, 200, nil)

      # System might be present but nil, or not present at all
      expect(result[:system]).to be_nil if result.key?(:system)
    end

    it "combines multiple system messages with newlines" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.system("You speak English"),
        Smolagents::ChatMessage.user("Hello")
      ]

      allow(builder).to receive(:format_messages).and_call_original

      result = builder.build_params(messages, nil, 0.7, 200, nil)

      system = result[:system]
      expect(system).to include("helpful")
      expect(system).to include("English")
    end

    it "includes tools when provided" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      tool = double(name: "search", description: "Search")

      allow(builder).to receive(:format_tools).with([tool]).and_return([{ name: "search" }])

      result = builder.build_params(messages, nil, 0.7, 200, [tool])

      expect(result).to have_key(:tools)
    end
  end

  describe "#build_stream_params" do
    before do
      allow(builder).to receive_messages(format_messages: [{ role: "user", content: "Hello" }], format_tools: [])
    end

    it "returns hash for streaming" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_stream_params(messages)

      expect(result).to be_a(Hash)
    end

    it "includes stream: true" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_stream_params(messages)

      expect(result).to have_key(:stream)
      expect(result[:stream]).to be true
    end

    it "extracts system message" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      allow(builder).to receive(:format_messages).and_call_original

      result = builder.build_stream_params(messages)

      expect(result).to have_key(:system)
    end

    it "includes temperature from instance variable" do
      builder.instance_variable_set(:@temperature, 0.5)
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_stream_params(messages)

      expect(result[:temperature]).to eq(0.5)
    end

    it "includes max_tokens from instance variable" do
      builder.instance_variable_set(:@max_tokens, 500)
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_stream_params(messages)

      expect(result[:max_tokens]).to eq(500)
    end

    it "includes model_id" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = builder.build_stream_params(messages)

      expect(result).to have_key(:model)
      expect(result[:model]).to eq("claude-3-sonnet-20240229")
    end
  end

  describe "#extract_system_message" do
    it "extracts system messages" do
      messages = [
        Smolagents::ChatMessage.system("System prompt"),
        Smolagents::ChatMessage.user("Hello")
      ]

      system, user = builder.send(:extract_system_message, messages)

      expect(system).to eq("System prompt")
      expect(user.length).to eq(1)
      expect(user[0].role).to eq(:user)
    end

    it "returns nil system when no system messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      system, user = builder.send(:extract_system_message, messages)

      expect(system).to be_nil
      expect(user.length).to eq(1)
    end

    it "combines multiple system messages with newline separator" do
      messages = [
        Smolagents::ChatMessage.system("System prompt 1"),
        Smolagents::ChatMessage.system("System prompt 2"),
        Smolagents::ChatMessage.user("Hello")
      ]

      system, = builder.send(:extract_system_message, messages)

      expect(system).to eq("System prompt 1\n\nSystem prompt 2")
    end

    it "filters out system messages from returned messages" do
      messages = [
        Smolagents::ChatMessage.system("System"),
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi"),
        Smolagents::ChatMessage.system("More system")
      ]

      _, user = builder.send(:extract_system_message, messages)

      expect(user.length).to eq(2)
      expect(user.map(&:role)).to eq(%i[user assistant])
    end

    it "handles empty message array" do
      system, user = builder.send(:extract_system_message, [])

      expect(system).to be_nil
      expect(user).to eq([])
    end

    it "preserves message order for non-system messages" do
      messages = [
        Smolagents::ChatMessage.user("First"),
        Smolagents::ChatMessage.assistant("Second"),
        Smolagents::ChatMessage.user("Third")
      ]

      _, user = builder.send(:extract_system_message, messages)

      contents = user.map(&:content)
      expect(contents).to eq(%w[First Second Third])
    end
  end

  describe "#format_tools" do
    it "wraps tools in Anthropic format" do
      tool = double(name: "search", description: "Search the web")

      allow(builder).to receive_messages(extract_tool_schema: {
                                           name: "search",
                                           description: "Search the web",
                                           properties: { query: { type: "string" } },
                                           required: ["query"]
                                         }, build_parameters_schema: {
                                           type: "object",
                                           properties: { query: { type: "string" } },
                                           required: ["query"]
                                         })

      result = builder.send(:format_tools, [tool])

      expect(result).to be_an(Array)
      expect(result[0]).to have_key(:name)
      expect(result[0]).to have_key(:description)
      expect(result[0]).to have_key(:input_schema)
    end

    it "includes input_schema in Anthropic format" do
      tool = double(name: "calc", description: "Calculate")

      allow(builder).to receive_messages(extract_tool_schema: {
                                           name: "calc",
                                           description: "Calculate",
                                           properties: {},
                                           required: []
                                         }, build_parameters_schema: {
                                           type: "object",
                                           properties: {},
                                           required: []
                                         })

      result = builder.send(:format_tools, [tool])

      expect(result[0]).to have_key(:input_schema)
      expect(result[0][:input_schema]).to have_key(:type)
    end
  end
end
