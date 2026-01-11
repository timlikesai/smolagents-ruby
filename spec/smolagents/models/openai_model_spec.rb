# frozen_string_literal: true

require "smolagents/models/model"
require "smolagents/models/openai_model"

RSpec.describe Smolagents::OpenAIModel do
  let(:api_key) { "test-api-key" }
  let(:model_id) { "gpt-4" }

  describe "#initialize" do
    it "creates a model with required parameters" do
      model = described_class.new(model_id: model_id, api_key: api_key)
      expect(model.model_id).to eq(model_id)
    end

    it "raises LoadError with helpful message when ruby-openai gem is not installed" do
      # Hide the openai constant temporarily to simulate gem not being installed
      openai_const = Object.send(:remove_const, :OpenAI) if defined?(OpenAI)

      begin
        allow_any_instance_of(described_class).to receive(:require).with("openai").and_raise(LoadError)

        expect do
          described_class.new(model_id: model_id, api_key: api_key)
        end.to raise_error(LoadError, /ruby-openai gem required for OpenAI models/)
      ensure
        # Restore the constant
        Object.const_set(:OpenAI, openai_const) if openai_const
      end
    end

    it "uses ENV['OPENAI_API_KEY'] if no api_key provided" do
      ENV["OPENAI_API_KEY"] = "env-key"
      model = described_class.new(model_id: model_id)
      expect(model.model_id).to eq(model_id)
      ENV.delete("OPENAI_API_KEY")
    end

    it "accepts custom api_base" do
      model = described_class.new(
        model_id: model_id,
        api_key: api_key,
        api_base: "http://localhost:1234/v1"
      )
      expect(model.model_id).to eq(model_id)
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

    before do
      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(mock_response)
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

      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(mock_response_with_tools)

      response = model.generate(messages)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.size).to eq(1)
      expect(response.tool_calls.first.name).to eq("search")
      expect(response.tool_calls.first.arguments).to eq({ "query" => "test" })
    end

    it "passes stop sequences" do
      expect_any_instance_of(OpenAI::Client).to receive(:chat) do |_instance, parameters:|
        expect(parameters[:stop]).to eq(["STOP"])
        mock_response
      end

      model.generate(messages, stop_sequences: ["STOP"])
    end

    it "passes temperature override" do
      expect_any_instance_of(OpenAI::Client).to receive(:chat) do |_instance, parameters:|
        expect(parameters[:temperature]).to eq(0.9)
        mock_response
      end

      model.generate(messages, temperature: 0.9)
    end

    it "formats tools when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = { "query" => { "type" => "string", "description" => "Search query" } }
        self.output_type = "string"
      end.new

      expect_any_instance_of(OpenAI::Client).to receive(:chat) do |_instance, parameters:|
        expect(parameters[:tools]).to be_an(Array)
        expect(parameters[:tools].first[:function][:name]).to eq("search")
        mock_response
      end

      model.generate(messages, tools_to_call_from: [search_tool])
    end

    it "handles API errors" do
      error_response = { "error" => { "message" => "Rate limit exceeded" } }
      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(error_response)

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
    end

    it "retries on Faraday errors" do
      call_count = 0
      allow_any_instance_of(OpenAI::Client).to receive(:chat) do
        call_count += 1
        raise Faraday::ConnectionFailed, "Connection failed" if call_count < 3

        mock_response
      end

      response = model.generate(messages)
      expect(response.content).to eq("Hello! How can I help you?")
      expect(call_count).to eq(3)
    end
  end

  describe "#format_messages_for_api" do
    let(:model) { described_class.new(model_id: model_id, api_key: api_key) }

    it "formats simple messages" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Hello")
      ]

      formatted = model.send(:format_messages_for_api, messages)

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

      formatted = model.send(:format_messages_for_api, messages)

      expect(formatted.first[:role]).to eq("assistant")
      expect(formatted.first[:tool_calls]).to be_an(Array)
      expect(formatted.first[:tool_calls].first[:function][:name]).to eq("search")
    end
  end
end
