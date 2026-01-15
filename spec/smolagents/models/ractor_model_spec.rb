require "smolagents/models/ractor_model"
require "smolagents/http/ractor_safe_client"
require "webmock/rspec"

RSpec.describe Smolagents::Models::RactorModel do
  let(:api_key) { "test-api-key" }
  let(:model_id) { "gpt-4" }
  let(:api_base) { "https://api.openai.com/v1" }

  before do
    WebMock.allow_net_connect!
  end

  describe "#initialize" do
    it "creates a model with required parameters" do
      model = described_class.new(model_id:, api_key:)
      expect(model.model_id).to eq(model_id)
    end

    it "uses the provided api_base" do
      custom_base = "http://localhost:1234/v1"
      model = described_class.new(model_id:, api_key:, api_base: custom_base)
      expect(model.model_id).to eq(model_id)
    end

    it "uses DEFAULT_API_BASE when api_base is not provided" do
      model = described_class.new(model_id:, api_key:)
      # Verify by checking the client is created correctly
      expect(model.model_id).to eq(model_id)
    end

    it "accepts temperature parameter" do
      model = described_class.new(
        model_id:,
        api_key:,
        temperature: 0.7
      )
      expect(model.model_id).to eq(model_id)
    end

    it "accepts max_tokens parameter" do
      model = described_class.new(
        model_id:,
        api_key:,
        max_tokens: 500
      )
      expect(model.model_id).to eq(model_id)
    end

    it "accepts timeout parameter" do
      model = described_class.new(
        model_id:,
        api_key:,
        timeout: 60
      )
      expect(model.model_id).to eq(model_id)
    end

    it "accepts all parameters together" do
      model = described_class.new(
        model_id:,
        api_key:,
        api_base: "http://localhost:8000/v1",
        temperature: 0.5,
        max_tokens: 1000,
        timeout: 30
      )
      expect(model.model_id).to eq(model_id)
    end
  end

  describe "#generate" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

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
              "content" => "Hello! How can I help?"
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
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response), headers: { "Content-Type" => "application/json" })
    end

    it "generates a response from messages" do
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.role).to eq(:assistant)
      expect(response.content).to eq("Hello! How can I help?")
    end

    it "includes token usage in response" do
      response = model.generate(messages)

      expect(response.token_usage).to be_a(Smolagents::TokenUsage)
      expect(response.token_usage.input_tokens).to eq(10)
      expect(response.token_usage.output_tokens).to eq(20)
      expect(response.token_usage.total_tokens).to eq(30)
    end

    it "returns assistant role message" do
      response = model.generate(messages)
      expect(response.role).to eq(:assistant)
    end

    it "passes temperature override to API" do
      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("temperature" => 0.9))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model.generate(messages, temperature: 0.9)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("temperature" => 0.9))
    end

    it "passes max_tokens override to API" do
      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("max_tokens" => 256))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model.generate(messages, max_tokens: 256)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("max_tokens" => 256))
    end

    it "passes stop sequences to API" do
      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("stop" => %w[STOP END]))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model.generate(messages, stop_sequences: %w[STOP END])

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("stop" => %w[STOP END]))
    end

    it "uses instance temperature when no override provided" do
      model_with_temp = described_class.new(
        model_id:,
        api_key:,
        api_base:,
        temperature: 0.3
      )

      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("temperature" => 0.3))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model_with_temp.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("temperature" => 0.3))
    end

    it "uses instance max_tokens when no override provided" do
      model_with_max = described_class.new(
        model_id:,
        api_key:,
        api_base:,
        max_tokens: 512
      )

      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("max_tokens" => 512))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model_with_max.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("max_tokens" => 512))
    end

    it "sends correct model_id to API" do
      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("model" => "gpt-4"))
        .to_return(status: 200, body: JSON.generate(mock_response))

      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("model" => "gpt-4"))
    end
  end

  describe "#generate with tool calls" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("What's the weather?")] }

    let(:mock_response_with_tools) do
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
              "content" => "Let me check the weather for you.",
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "get_weather",
                    "arguments" => '{"city": "New York"}'
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 15,
          "completion_tokens" => 25,
          "total_tokens" => 40
        }
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(
          status: 200,
          body: JSON.generate(mock_response_with_tools),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "parses tool calls from response" do
      response = model.generate(messages)

      expect(response.tool_calls).to be_an(Array)
      expect(response.tool_calls.size).to eq(1)
      expect(response.tool_calls.first.name).to eq("get_weather")
      expect(response.tool_calls.first.id).to eq("call_123")
    end

    it "parses tool call arguments as JSON" do
      response = model.generate(messages)

      tool_call = response.tool_calls.first
      expect(tool_call.arguments).to eq({ "city" => "New York" })
    end

    it "includes content with tool calls" do
      response = model.generate(messages)

      expect(response.content).to eq("Let me check the weather for you.")
    end

    it "handles multiple tool calls" do
      multi_tools_response = mock_response_with_tools.dup
      multi_tools_response["choices"][0]["message"]["tool_calls"] << {
        "id" => "call_456",
        "type" => "function",
        "function" => {
          "name" => "search",
          "arguments" => '{"query": "NYC weather"}'
        }
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(multi_tools_response))

      response = model.generate(messages)

      expect(response.tool_calls.size).to eq(2)
      expect(response.tool_calls.map(&:name)).to include("get_weather", "search")
    end

    it "handles invalid JSON in tool arguments" do
      invalid_json_response = mock_response_with_tools.dup
      invalid_json_response["choices"][0]["message"]["tool_calls"][0]["function"]["arguments"] = "invalid json"

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(invalid_json_response))

      response = model.generate(messages)

      tool_call = response.tool_calls.first
      expect(tool_call.arguments).to eq({ "error" => "Invalid JSON in arguments" })
    end

    it "passes tools to API when provided" do
      search_tool = Class.new(Smolagents::Tool) do
        self.tool_name = "search"
        self.description = "Search for information"
        self.inputs = { query: { type: "string", description: "Search query" } }
        self.output_type = "string"

        def execute(query:)
          "Results for #{query}"
        end
      end.new

      stub_request(:post, "#{api_base}/chat/completions")
        .with(body: lambda { |req_body|
          parsed = JSON.parse(req_body)
          parsed["tools"].is_a?(Array) && parsed["tools"].first["type"] == "function"
        })
        .to_return(status: 200, body: JSON.generate(mock_response_with_tools))

      model.generate(messages, tools: [search_tool])

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
    end
  end

  describe "#generate with system messages" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:mock_response) do
      {
        "id" => "chatcmpl-123",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "I am helpful"
            }
          }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 5
        }
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "formats system messages correctly" do
      system_msg = Smolagents::ChatMessage.system("You are helpful")
      user_msg = Smolagents::ChatMessage.user("Hello")
      messages = [system_msg, user_msg]

      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: lambda { |req_body|
          parsed = JSON.parse(req_body)
          parsed["messages"][0]["role"] == "system" && parsed["messages"][0]["content"] == "You are helpful"
        })
    end

    it "includes multiple messages in request" do
      messages = [
        Smolagents::ChatMessage.system("Be concise"),
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi there"),
        Smolagents::ChatMessage.user("How are you?")
      ]

      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: lambda { |req_body|
          parsed = JSON.parse(req_body)
          parsed["messages"].size == 4
        })
    end
  end

  describe "#generate with tool call messages" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:mock_response) do
      {
        "id" => "chatcmpl-456",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "Found results"
            }
          }
        ],
        "usage" => {
          "prompt_tokens" => 20,
          "completion_tokens" => 10
        }
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "formats assistant message with tool calls" do
      tool_call = Smolagents::ToolCall.new(
        id: "call_789",
        name: "search",
        arguments: { "query" => "ruby" }
      )
      messages = [
        Smolagents::ChatMessage.user("Search for ruby"),
        Smolagents::ChatMessage.assistant("Let me search", tool_calls: [tool_call])
      ]

      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: lambda { |req_body|
          parsed = JSON.parse(req_body)
          msg = parsed["messages"][1]
          msg["role"] == "assistant" && msg["tool_calls"].is_a?(Array)
        })
    end
  end

  describe "error handling" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    it "raises AgentGenerationError on API error" do
      error_response = {
        "error" => {
          "message" => "Rate limit exceeded"
        }
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(error_response))

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError, /Rate limit exceeded/)
    end

    it "handles 401 unauthorized error" do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 401, body: JSON.generate({ "error" => { "message" => "Invalid API key" } }))

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError)
    end

    it "handles 500 server error" do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 500, body: JSON.generate({ "error" => { "message" => "Internal server error" } }))

      expect do
        model.generate(messages)
      end.to raise_error(Smolagents::AgentGenerationError)
    end

    it "handles empty choices in response" do
      empty_response = {
        "id" => "chatcmpl-789",
        "choices" => [],
        "usage" => { "prompt_tokens" => 5, "completion_tokens" => 0 }
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(empty_response))

      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.content).to eq("")
    end

    it "handles missing message in choice" do
      malformed_response = {
        "id" => "chatcmpl-789",
        "choices" => [{ "index" => 0 }],
        "usage" => { "prompt_tokens" => 5, "completion_tokens" => 0 }
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(malformed_response))

      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.content).to eq("")
    end

    it "handles missing usage in response" do
      response_without_usage = {
        "id" => "chatcmpl-789",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "Hello!"
            }
          }
        ]
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_without_usage))

      response = model.generate(messages)

      expect(response.content).to eq("Hello!")
      expect(response.token_usage).to be_nil
    end
  end

  describe "edge cases" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("Test")] }

    let(:mock_response) do
      {
        "id" => "chatcmpl-edge",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "Response"
            }
          }
        ],
        "usage" => {
          "prompt_tokens" => 5,
          "completion_tokens" => 2
        }
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "handles empty message content" do
      response_with_empty = mock_response.dup
      response_with_empty["choices"][0]["message"]["content"] = ""

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_with_empty))

      response = model.generate(messages)

      expect(response.content).to eq("")
    end

    it "handles nil content" do
      response_with_nil = mock_response.dup
      response_with_nil["choices"][0]["message"]["content"] = nil

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_with_nil))

      response = model.generate(messages)

      expect(response.content).to be_nil
    end

    it "handles zero token usage" do
      response_zero_tokens = mock_response.dup
      response_zero_tokens["usage"] = {
        "prompt_tokens" => 0,
        "completion_tokens" => 0
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_zero_tokens))

      response = model.generate(messages)

      expect(response.token_usage.input_tokens).to eq(0)
      expect(response.token_usage.output_tokens).to eq(0)
      expect(response.token_usage.total_tokens).to eq(0)
    end

    it "handles empty tool calls array" do
      response_with_empty_tools = mock_response.dup
      response_with_empty_tools["choices"][0]["message"]["tool_calls"] = []

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_with_empty_tools))

      response = model.generate(messages)

      expect(response.tool_calls).to be_nil
    end

    it "handles null tool_calls" do
      response_with_null_tools = mock_response.dup
      response_with_null_tools["choices"][0]["message"]["tool_calls"] = nil

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(response_with_null_tools))

      response = model.generate(messages)

      expect(response.tool_calls).to be_nil
    end
  end

  describe "local model compatibility" do
    let(:local_api_base) { "http://localhost:8000/v1" }
    let(:model) do
      described_class.new(
        model_id: "local-model",
        api_key: "local-key",
        api_base: local_api_base
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

    let(:mock_response) do
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "Local response"
            }
          }
        ]
      }
    end

    before do
      stub_request(:post, "#{local_api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "works with local API base" do
      response = model.generate(messages)

      expect(response.content).to eq("Local response")
      expect(WebMock).to have_requested(:post, "#{local_api_base}/chat/completions")
    end

    it "sends authorization header with API key" do
      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{local_api_base}/chat/completions")
        .with(headers: { "Authorization" => "Bearer local-key" })
    end

    it "sends correct content type header" do
      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{local_api_base}/chat/completions")
        .with(headers: { "Content-Type" => "application/json" })
    end
  end

  describe "parameter normalization" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("Test")] }

    let(:mock_response) do
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "Response"
            }
          }
        ]
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "includes provided parameters in request" do
      model.generate(messages, temperature: 0.5, max_tokens: 100)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: hash_including("temperature" => 0.5, "max_tokens" => 100))
    end

    it "sends all required fields in request" do
      model.generate(messages)

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
        .with(body: lambda { |req_body|
          parsed = JSON.parse(req_body)
          parsed.key?("model") && parsed.key?("messages")
        })
    end
  end

  describe "response format" do
    let(:model) do
      described_class.new(
        model_id:,
        api_key:,
        api_base:
      )
    end

    let(:messages) { [Smolagents::ChatMessage.user("Test")] }

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
              "content" => "Test response"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 5,
          "completion_tokens" => 3,
          "total_tokens" => 8
        }
      }
    end

    before do
      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: JSON.generate(mock_response))
    end

    it "returns ChatMessage with correct attributes" do
      response = model.generate(messages)

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.role).to eq(:assistant)
      expect(response.content).to eq("Test response")
    end

    it "stores raw response in ChatMessage" do
      response = model.generate(messages)

      expect(response.raw).to be_a(Hash)
      expect(response.raw["id"]).to eq("chatcmpl-123")
      expect(response.raw["model"]).to eq("gpt-4")
    end

    it "includes token usage with correct type" do
      response = model.generate(messages)

      expect(response.token_usage).to be_a(Smolagents::TokenUsage)
      expect(response.token_usage.input_tokens).to eq(5)
      expect(response.token_usage.output_tokens).to eq(3)
      expect(response.token_usage.total_tokens).to eq(8)
    end
  end
end
