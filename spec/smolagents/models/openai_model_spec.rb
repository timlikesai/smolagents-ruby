require "smolagents/models/model"
require "smolagents/models/openai_model"

begin
  require "openai"
rescue LoadError
end

RSpec.describe Smolagents::OpenAIModel do
  let(:api_key) { "test-api-key" }
  let(:model_id) { "gpt-4" }

  let(:mock_response) do
    {
      "id" => "chatcmpl-123",
      "object" => "chat.completion",
      "created" => 1_677_652_288,
      "model" => "gpt-4",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "Hello! How can I help you?"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 20,
        "total_tokens" => 30
      }
    }
  end

  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
    Stoplight.default_notifiers = []
  end

  describe "#initialize" do
    it "creates a model with required parameters" do
      model = described_class.new(model_id:, api_key:, client: mock_client)
      expect(model.model_id).to eq(model_id)
    end

    it "uses ENV['OPENAI_API_KEY'] if no api_key provided" do
      ENV["OPENAI_API_KEY"] = "env-key"
      model = described_class.new(model_id:, client: mock_client)
      expect(model.model_id).to eq(model_id)
      ENV.delete("OPENAI_API_KEY")
    end

    it "accepts custom api_base" do
      model = described_class.new(
        model_id:,
        api_key:,
        api_base: "http://localhost:1234/v1",
        client: mock_client
      )
      expect(model.model_id).to eq(model_id)
    end

    it "accepts temperature and max_tokens" do
      model = described_class.new(
        model_id:,
        api_key:,
        temperature: 0.5,
        max_tokens: 100,
        client: mock_client
      )
      expect(model.model_id).to eq(model_id)
    end

    it "accepts injected client" do
      custom_client = instance_double(OpenAI::Client)
      model = described_class.new(model_id:, api_key:, client: custom_client)
      expect(model.instance_variable_get(:@client)).to eq(custom_client)
    end
  end

  describe "#generate" do
    let(:model) { described_class.new(model_id:, api_key:, client: mock_client) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    before do
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    it "generates a response" do
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.role).to eq(:assistant)
      expect(response.content).to eq("Hello! How can I help you?")
    end

    it "includes token usage" do
      response = model.generate(messages)

      expect(response.token_usage).to be_a(Smolagents::TokenUsage)
      expect(response.token_usage.input_tokens).to eq(10)
      expect(response.token_usage.output_tokens).to eq(20)
      expect(response.token_usage.total_tokens).to eq(30)
    end

    it "handles tool calls" do
      mock_response_with_tools = mock_response.dup
      mock_response_with_tools["choices"] = [mock_response["choices"][0].dup]
      mock_response_with_tools["choices"][0]["message"] = mock_response["choices"][0]["message"].dup
      mock_response_with_tools["choices"][0]["message"]["tool_calls"] = [
        {
          "id" => "call_123",
          "type" => "function",
          "function" => {
            "name" => "search",
            "arguments" => '{"query": "test"}'
          }
        }
      ]

      allow(mock_client).to receive(:chat).and_return(mock_response_with_tools)

      response = model.generate(messages)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.size).to eq(1)
      expect(response.tool_calls.first.name).to eq("search")
      expect(response.tool_calls.first.arguments).to eq({ "query" => "test" })
    end

    it "passes stop sequences" do
      allow(mock_client).to receive(:chat) do |parameters:|
        expect(parameters[:stop]).to eq(["STOP"])
        mock_response
      end

      model.generate(messages, stop_sequences: ["STOP"])
    end

    it "passes temperature override" do
      allow(mock_client).to receive(:chat) do |parameters:|
        expect(parameters[:temperature]).to eq(0.9)
        mock_response
      end

      model.generate(messages, temperature: 0.9)
    end

    it "formats tools when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"
      end.new

      allow(mock_client).to receive(:chat) do |parameters:|
        expect(parameters[:tools]).to be_an(Array)
        expect(parameters[:tools].first[:function][:name]).to eq("search")
        mock_response
      end

      model.generate(messages, tools_to_call_from: [search_tool])
    end

    it "handles API errors" do
      error_response = { "error" => { "message" => "Rate limit exceeded" } }
      allow(mock_client).to receive(:chat).and_return(error_response)

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
    end

    it "retries on Faraday errors" do
      call_count = 0
      allow(mock_client).to receive(:chat) do
        call_count += 1
        raise Faraday::ConnectionFailed, "Connection failed" if call_count < 3

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(3)
    end
  end

  describe "#format_messages" do
    let(:model) { described_class.new(model_id:, api_key:, client: mock_client) }

    it "formats simple messages" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      formatted = model.send(:format_messages, messages)

      expect(formatted).to eq([
                                { role: "system", content: "You are helpful" },
                                { role: "user", content: "Hello" }
                              ])
    end

    it "formats messages with tool calls" do
      tool_call = Smolagents::ToolCall.new(
        id: "call_123",
        name: "search",
        arguments: { "query" => "test" }
      )
      messages = [
        Smolagents::ChatMessage.assistant("Let me search", tool_calls: [tool_call])
      ]

      formatted = model.send(:format_messages, messages)

      expect(formatted.first[:role]).to eq("assistant")
      expect(formatted.first[:tool_calls]).to be_an(Array)
      expect(formatted.first[:tool_calls].first[:function][:name]).to eq("search")
    end
  end

  describe "circuit breaker integration" do
    let(:model) { described_class.new(model_id:, api_key:, client: mock_client) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    it "opens circuit after multiple API failures" do
      allow(mock_client).to receive(:chat).and_raise(Faraday::ConnectionFailed, "Connection failed")

      3.times do
        expect { model.generate(messages) }.to raise_error(Faraday::ConnectionFailed)
      end

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError,
                         /Service unavailable.*circuit open.*openai_api/)
    end

    it "allows successful calls through" do
      simple_response = {
        "id" => "chatcmpl-123",
        "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello!" } }]
      }
      allow(mock_client).to receive(:chat).and_return(simple_response)

      5.times do
        response = model.generate(messages)
        expect(response.content).to eq("Hello!")
      end
    end
  end
end
