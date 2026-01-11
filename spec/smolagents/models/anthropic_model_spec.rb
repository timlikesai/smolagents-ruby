# frozen_string_literal: true

require "smolagents/models/model"
require "smolagents/models/anthropic_model"

RSpec.describe Smolagents::AnthropicModel do
  let(:api_key) { "test-api-key" }
  let(:model_id) { "claude-3-5-sonnet-20241022" }

  describe "#initialize" do
    it "creates a model with required parameters" do
      model = described_class.new(model_id: model_id, api_key: api_key)
      expect(model.model_id).to eq(model_id)
    end

    it "uses ENV['ANTHROPIC_API_KEY'] if no api_key provided" do
      ENV["ANTHROPIC_API_KEY"] = "env-key"
      model = described_class.new(model_id: model_id)
      expect(model.model_id).to eq(model_id)
      ENV.delete("ANTHROPIC_API_KEY")
    end

    it "accepts temperature and max_tokens" do
      model = described_class.new(
        model_id: model_id,
        api_key: api_key,
        temperature: 0.5,
        max_tokens: 100
      )
      expect(model.model_id).to eq(model_id)
    end
  end

  describe "#generate" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }
    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    let(:mock_response) do
      {
        "id" => "msg_123",
        "type" => "message",
        "role" => "assistant",
        "content" => [
          {
            "type" => "text",
            "text" => "Hello! How can I help you?"
          }
        ],
        "model" => "claude-3-5-sonnet-20241022",
        "stop_reason" => "end_turn",
        "usage" => {
          "input_tokens" => 10,
          "output_tokens" => 20
        }
      }
    end

    before do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response)
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
      mock_response_with_tools["content"] << {
        "type" => "tool_use",
        "id" => "toolu_123",
        "name" => "search",
        "input" => { "query" => "test" }
      }

      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(mock_response_with_tools)

      response = model.generate(messages)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.size).to eq(1)
      expect(response.tool_calls.first.name).to eq("search")
      expect(response.tool_calls.first.arguments).to eq({ "query" => "test" })
    end

    it "extracts system messages separately" do
      messages_with_system = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, params:|
        expect(params[:system]).to eq("You are helpful")
        expect(params[:messages].size).to eq(1)
        expect(params[:messages].first[:role]).to eq("user")
        mock_response
      end

      model.generate(messages_with_system)
    end

    it "passes stop sequences" do
      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, params:|
        expect(params[:stop_sequences]).to eq(["STOP"])
        mock_response
      end

      model.generate(messages, stop_sequences: ["STOP"])
    end

    it "formats tools when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = { "query" => { "type" => "string", "description" => "Search query" } }
        self.output_type = "string"
      end.new

      expect_any_instance_of(Anthropic::Client).to receive(:messages) do |_, params:|
        expect(params[:tools]).to be_an(Array)
        expect(params[:tools].first[:name]).to eq("search")
        expect(params[:tools].first[:input_schema]).to be_a(Hash)
        mock_response
      end

      model.generate(messages, tools_to_call_from: [search_tool])
    end

    it "handles API errors" do
      error_response = { "error" => { "message" => "Rate limit exceeded" } }
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(error_response)

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
    end

    it "retries on Faraday errors" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Faraday::ConnectionFailed, "Connection failed" if call_count < 3

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(3)
    end

    it "retries on Anthropic::Error" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Anthropic::Error, "API error" if call_count < 2

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(2)
    end

    it "does not retry on AgentGenerationError" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Smolagents::AgentGenerationError, "Logic error"
      end

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Logic error/)
      expect(call_count).to eq(1)
    end

    it "does not retry on InterpreterError" do
      call_count = 0
      allow_any_instance_of(Anthropic::Client).to receive(:messages) do
        call_count += 1
        raise Smolagents::InterpreterError, "Interpreter error"
      end

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::InterpreterError, /Interpreter error/)
      expect(call_count).to eq(1)
    end
  end

  describe "#extract_system_message" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "separates system from user messages" do
      messages = [
        Smolagents::ChatMessage.system("System prompt"),
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi")
      ]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to eq("System prompt")
      expect(user_messages.size).to eq(2)
      expect(user_messages.map(&:role)).to eq(%i[user assistant])
    end

    it "combines multiple system messages" do
      messages = [
        Smolagents::ChatMessage.system("First"),
        Smolagents::ChatMessage.system("Second"),
        Smolagents::ChatMessage.user("Hello")
      ]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to eq("First\n\nSecond")
      expect(user_messages.size).to eq(1)
    end

    it "returns nil if no system messages" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      system, user_messages = model.send(:extract_system_message, messages)

      expect(system).to be_nil
      expect(user_messages.size).to eq(1)
    end
  end
end
