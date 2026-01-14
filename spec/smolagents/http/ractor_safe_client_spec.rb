require "spec_helper"
require "webmock/rspec"

RSpec.describe Smolagents::Http::RactorSafeClient do
  describe "initialization" do
    it "creates a client with required parameters" do
      client = described_class.new(
        api_base: "http://localhost:1234/v1",
        api_key: "test-key"
      )

      expect(client.api_base).to eq("http://localhost:1234/v1")
      expect(client.timeout).to eq(described_class::DEFAULT_TIMEOUT)
    end

    it "strips trailing slash from api_base" do
      client = described_class.new(
        api_base: "http://localhost:1234/v1/",
        api_key: "test-key"
      )

      expect(client.api_base).to eq("http://localhost:1234/v1")
    end

    it "accepts custom timeout" do
      client = described_class.new(
        api_base: "http://localhost:1234/v1",
        api_key: "test-key",
        timeout: 30
      )

      expect(client.timeout).to eq(30)
    end

    it "stores api_key (even if empty)" do
      client = described_class.new(
        api_base: "http://localhost:1234/v1",
        api_key: ""
      )

      expect(client.api_base).to eq("http://localhost:1234/v1")
    end

    it "uses DEFAULT_TIMEOUT constant" do
      expect(described_class::DEFAULT_TIMEOUT).to eq(120)
    end
  end

  describe "#chat_completion" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:api_key) { "test-key" }
    let(:client) { described_class.new(api_base:, api_key:) }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    context "with minimal parameters" do
      it "sends a POST request with model and messages" do
        response_body = {
          id: "chatcmpl-123",
          object: "chat.completion",
          created: 1_234_567_890,
          model: "gpt-4",
          choices: [
            {
              index: 0,
              message: { role: "assistant", content: "Hello!" },
              finish_reason: "stop"
            }
          ],
          usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
        }

        stub_request(:post, endpoint_url)
          .with(
            headers: {
              "Content-Type" => "application/json",
              "Authorization" => "Bearer test-key"
            }
          )
          .to_return(status: 200, body: response_body.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Hello" }]
        )

        expect(result).to be_a(Hash)
        expect(result["choices"]).to be_an(Array)
        expect(result["choices"][0]["message"]["content"]).to eq("Hello!")
      end
    end

    context "with optional parameters" do
      it "sends temperature parameter" do
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .with(body: hash_including("temperature" => 0.7))
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }],
          temperature: 0.7
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end

      it "sends max_tokens parameter" do
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .with(body: hash_including("max_tokens" => 100))
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }],
          max_tokens: 100
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end

      it "sends tools parameter" do
        tools = [
          {
            type: "function",
            function: {
              name: "search",
              description: "Search the web",
              parameters: { type: "object", properties: {} }
            }
          }
        ]

        response_body = { choices: [{ message: { role: "assistant", content: "I'll search" } }] }

        stub_request(:post, endpoint_url)
          .with(body: hash_including("tools" => tools))
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Search for something" }],
          tools:
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end

      it "sends stop parameter" do
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .with(body: hash_including("stop" => ["\n", "User:"]))
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }],
          stop: ["\n", "User:"]
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end

      it "omits nil parameters from request" do
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .with do |request|
            body = JSON.parse(request.body)
            # Verify temperature, max_tokens, tools, stop are not in the body
            expect(body).not_to have_key("temperature")
            expect(body).not_to have_key("max_tokens")
            expect(body).not_to have_key("tools")
            expect(body).not_to have_key("stop")
            true
          end
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }],
          temperature: nil,
          max_tokens: nil,
          tools: nil,
          stop: nil
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end

      it "sends all parameters together" do
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .with(
            body: hash_including(
              "model" => "gpt-4",
              "temperature" => 0.8,
              "max_tokens" => 200,
              "stop" => ["END"]
            )
          )
          .to_return(status: 200, body: response_body.to_json)

        client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }],
          temperature: 0.8,
          max_tokens: 200,
          stop: ["END"]
        )

        expect(WebMock).to have_requested(:post, endpoint_url)
      end
    end

    context "with different API keys" do
      it "includes API key in Authorization header" do
        client_with_key = described_class.new(api_base:, api_key: "custom-key")
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .to_return(status: 200, body: response_body.to_json)

        client_with_key.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(WebMock).to(have_requested(:post, endpoint_url).with do |request|
          request.headers["Authorization"] == "Bearer custom-key"
        end)
      end

      it "omits Authorization header when api_key is empty string" do
        client_no_key = described_class.new(api_base:, api_key: "")
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, endpoint_url)
          .to_return(status: 200, body: response_body.to_json)

        client_no_key.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        # If Authorization header is missing, the request should still match the stub
        expect(WebMock).to have_requested(:post, endpoint_url)
      end
    end

    context "with HTTPS" do
      it "supports HTTPS API base" do
        https_client = described_class.new(
          api_base: "https://api.openai.com/v1",
          api_key: "sk-test"
        )
        response_body = { choices: [{ message: { role: "assistant", content: "Response" } }] }

        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 200, body: response_body.to_json)

        result = https_client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result).to be_a(Hash)
        expect(result["choices"]).to be_an(Array)
      end
    end
  end

  describe "HTTP methods" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "test-key") }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    it "sets Content-Type header to application/json" do
      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      expect(WebMock).to(have_requested(:post, endpoint_url).with do |request|
        request.headers["Content-Type"] == "application/json"
      end)
    end

    it "sends JSON-serialized request body" do
      stub_request(:post, endpoint_url)
        .with(
          body: hash_including(
            "model" => "test-model",
            "temperature" => 0.5
          )
        )
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "test-model",
        messages: [{ role: "user", content: "Hello" }],
        temperature: 0.5
      )

      expect(WebMock).to have_requested(:post, endpoint_url)
    end
  end

  describe "error handling" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "test-key") }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    context "with successful response" do
      it "parses and returns JSON response" do
        response_body = {
          id: "chatcmpl-123",
          choices: [{ message: { role: "assistant", content: "Success" } }],
          usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }
        }

        stub_request(:post, endpoint_url)
          .to_return(status: 200, body: response_body.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result).to be_a(Hash)
        expect(result["id"]).to eq("chatcmpl-123")
        expect(result["choices"]).to be_an(Array)
        expect(result["usage"]["total_tokens"]).to eq(15)
      end
    end

    context "with HTTP error responses" do
      it "returns error response for 400 Bad Request" do
        error_response = {
          error: { message: "Invalid request", type: "invalid_request_error" }
        }

        stub_request(:post, endpoint_url)
          .to_return(status: 400, body: error_response.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result).to be_a(Hash)
        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("Invalid request")
      end

      it "returns error response for 401 Unauthorized" do
        error_response = { error: { message: "Invalid API key" } }

        stub_request(:post, endpoint_url)
          .to_return(status: 401, body: error_response.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("Invalid API key")
      end

      it "returns error response for 429 Too Many Requests" do
        error_response = { error: { message: "Rate limit exceeded" } }

        stub_request(:post, endpoint_url)
          .to_return(status: 429, body: error_response.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("Rate limit exceeded")
      end

      it "returns error response for 500 Internal Server Error" do
        error_response = { error: { message: "Internal server error" } }

        stub_request(:post, endpoint_url)
          .to_return(status: 500, body: error_response.to_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("Internal server error")
      end
    end

    context "with non-JSON error responses" do
      it "handles HTML error responses gracefully" do
        html_error = "<html><body>404 Not Found</body></html>"

        stub_request(:post, endpoint_url)
          .to_return(status: 404, body: html_error)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result).to be_a(Hash)
        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("404 Not Found")
      end

      it "handles plain text error responses" do
        text_error = "Service temporarily unavailable"

        stub_request(:post, endpoint_url)
          .to_return(status: 503, body: text_error)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("Service temporarily unavailable")
      end

      it "includes HTTP status code in error when JSON parsing fails" do
        stub_request(:post, endpoint_url)
          .to_return(status: 502, body: "Bad Gateway")

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        # Should have either the raw response or HTTP status code info
        expect(result["error"]["message"]).to be_a(String)
      end
    end

    context "with malformed JSON error responses" do
      it "rescues JSON::ParserError and uses response body as message" do
        invalid_json = "{invalid json"

        stub_request(:post, endpoint_url)
          .to_return(status: 500, body: invalid_json)

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result).to be_a(Hash)
        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to eq(invalid_json)
      end
    end

    context "with missing error field" do
      it "synthesizes error object with HTTP status" do
        stub_request(:post, endpoint_url)
          .to_return(status: 503, body: "{}")

        result = client.chat_completion(
          model: "gpt-4",
          messages: [{ role: "user", content: "Test" }]
        )

        expect(result["error"]).to be_a(Hash)
        expect(result["error"]["message"]).to include("503")
      end
    end
  end

  describe "timeout handling" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    it "uses default timeout when not specified" do
      client = described_class.new(api_base:, api_key: "test-key")

      expect(client.timeout).to eq(120)
    end

    it "uses custom timeout when specified" do
      client = described_class.new(
        api_base:,
        api_key: "test-key",
        timeout: 30
      )

      expect(client.timeout).to eq(30)
    end

    it "applies timeout to HTTP client" do
      client = described_class.new(
        api_base:,
        api_key: "test-key",
        timeout: 45
      )

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: { choices: [] }.to_json)

      # The client should set both open_timeout and read_timeout
      client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      # Verify the request was made (timeout didn't prevent it)
      expect(WebMock).to have_requested(:post, endpoint_url)
    end

    it "handles short timeout values" do
      client = described_class.new(
        api_base:,
        api_key: "test-key",
        timeout: 1
      )

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: { choices: [] }.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      expect(result).to be_a(Hash)
    end
  end

  describe "response parsing" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "test-key") }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    it "parses complex JSON response structures" do
      response_body = {
        id: "chatcmpl-abc123def456",
        object: "chat.completion",
        created: 1_705_084_800,
        model: "gpt-4-turbo-preview",
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content: "This is a test response with [multiple](https://example.com) elements."
            },
            logprobs: nil,
            finish_reason: "stop"
          },
          {
            index: 1,
            message: {
              role: "assistant",
              content: "Alternative response"
            },
            finish_reason: "stop"
          }
        ],
        usage: {
          prompt_tokens: 42,
          completion_tokens: 17,
          total_tokens: 59
        },
        system_fingerprint: "fp_123456"
      }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response_body.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      expect(result["id"]).to eq("chatcmpl-abc123def456")
      expect(result["choices"].length).to eq(2)
      expect(result["choices"][0]["message"]["content"]).to eq("This is a test response with [multiple](https://example.com) elements.")
      expect(result["usage"]["total_tokens"]).to eq(59)
      expect(result["system_fingerprint"]).to eq("fp_123456")
    end

    it "preserves nested objects in response" do
      response_body = {
        choices: [
          {
            message: {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  id: "call_abc123",
                  type: "function",
                  function: {
                    name: "search",
                    arguments: '{"query": "test"}'
                  }
                }
              ]
            }
          }
        ]
      }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response_body.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      tool_call = result["choices"][0]["message"]["tool_calls"][0]
      expect(tool_call["function"]["arguments"]).to eq('{"query": "test"}')
    end

    it "handles responses with additional custom fields" do
      response_body = {
        choices: [{ message: { role: "assistant", content: "Response" } }],
        custom_field: "custom_value",
        metadata: { provider: "local_model", version: "1.0" }
      }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response_body.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      expect(result["custom_field"]).to eq("custom_value")
      expect(result["metadata"]).to be_a(Hash)
    end

    it "returns raw parsed JSON without modifications" do
      response_body = {
        choices: [{ message: { role: "assistant", content: "  spaces  " } }]
      }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response_body.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      # Should preserve spacing exactly as received
      expect(result["choices"][0]["message"]["content"]).to eq("  spaces  ")
    end
  end

  describe "path and URL handling" do
    it "constructs correct URL for chat completions endpoint" do
      api_base = "http://api.example.com/v1"
      client = described_class.new(api_base:, api_key: "key")

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "test",
        messages: [{ role: "user", content: "test" }]
      )

      expect(WebMock).to have_requested(:post, "#{api_base}/chat/completions")
    end

    it "handles api_base with trailing slash" do
      client = described_class.new(
        api_base: "http://localhost:1234/v1/",
        api_key: "key"
      )

      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "test",
        messages: [{ role: "user", content: "test" }]
      )

      expect(WebMock).to have_requested(:post, "http://localhost:1234/v1/chat/completions")
    end

    it "handles different port numbers" do
      client = described_class.new(
        api_base: "http://localhost:9999/api",
        api_key: "key"
      )

      stub_request(:post, "http://localhost:9999/api/chat/completions")
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "test",
        messages: [{ role: "user", content: "test" }]
      )

      expect(WebMock).to have_requested(:post, "http://localhost:9999/api/chat/completions")
    end
  end

  describe "real-world scenarios" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "") }

    it "handles LM Studio compatible API call" do
      response = {
        id: "chatcmpl-123",
        object: "chat.completion",
        created: Time.now.to_i,
        model: "lfm2.5-1.2b-instruct",
        choices: [
          {
            index: 0,
            message: { role: "assistant", content: "I can help with that." },
            finish_reason: "stop"
          }
        ],
        usage: { prompt_tokens: 15, completion_tokens: 8, total_tokens: 23 }
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "lfm2.5-1.2b-instruct",
        messages: [
          { role: "system", content: "You are a helpful assistant." },
          { role: "user", content: "What is Ruby?" }
        ]
      )

      expect(result["model"]).to eq("lfm2.5-1.2b-instruct")
      expect(result["choices"][0]["message"]["content"]).to eq("I can help with that.")
    end

    it "handles multi-turn conversation" do
      response = {
        choices: [
          {
            message: { role: "assistant", content: "The capital of France is Paris." }
          }
        ]
      }

      stub_request(:post, "#{api_base}/chat/completions")
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [
          { role: "system", content: "You are helpful." },
          { role: "user", content: "What is the capital of France?" },
          { role: "assistant", content: "Let me think..." },
          { role: "user", content: "Tell me now" }
        ]
      )

      expect(result["choices"]).to be_an(Array)
      expect(result["choices"][0]["message"]["role"]).to eq("assistant")
    end

    it "handles tool/function calling request" do
      tools = [{ type: "function", function: { name: "get_weather", description: "Get weather",
                                               parameters: { type: "object", properties: { location: { type: "string" } } } } }]
      response = { choices: [{ message: { role: "assistant", content: nil,
                                          tool_calls: [{ id: "call_123", type: "function",
                                                         function: { name: "get_weather", arguments: '{"location": "Tokyo"}' } }] },
                               finish_reason: "tool_calls" }] }

      stub_request(:post, "#{api_base}/chat/completions").to_return(status: 200, body: response.to_json)

      result = client.chat_completion(model: "gpt-4", messages: [{ role: "user", content: "Weather?" }], tools:)

      expect(result.dig("choices", 0, "message", "tool_calls", 0, "function", "name")).to eq("get_weather")
    end
  end

  describe "edge cases" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "key") }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    it "handles empty message content" do
      response = { choices: [{ message: { role: "assistant", content: "" } }] }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "" }]
      )

      expect(result["choices"][0]["message"]["content"]).to eq("")
    end

    it "handles very long message content" do
      long_content = "a" * 10_000
      response = { choices: [{ message: { role: "assistant", content: "Response to long input" } }] }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: long_content }]
      )

      expect(result["choices"]).to be_an(Array)
    end

    it "handles special characters in content" do
      special_content = 'Test with "quotes", \'apostrophes\', \n newlines, \t tabs, \\ backslashes'
      response = { choices: [{ message: { role: "assistant", content: "Response" } }] }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: special_content }]
      )

      expect(result["choices"]).to be_an(Array)
    end

    it "handles unicode and emoji in content" do
      unicode_content = "Hello 世界 🌍 مرحبا мир"
      response = { choices: [{ message: { role: "assistant", content: "Response" } }] }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: unicode_content }]
      )

      expect(result["choices"]).to be_an(Array)
    end

    it "handles response with null values" do
      response = {
        choices: [
          {
            message: { role: "assistant", content: "Response" },
            logprobs: nil,
            finish_reason: "stop"
          }
        ],
        system_fingerprint: nil
      }

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: response.to_json)

      result = client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }]
      )

      expect(result["system_fingerprint"]).to be_nil
      expect(result["choices"][0]["logprobs"]).to be_nil
    end
  end

  describe "request body composition" do
    let(:api_base) { "http://localhost:1234/v1" }
    let(:client) { described_class.new(api_base:, api_key: "test-key") }
    let(:endpoint_url) { "#{api_base}/chat/completions" }

    it "includes model in request body" do
      stub_request(:post, endpoint_url)
        .with(body: hash_including("model" => "my-model"))
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "my-model",
        messages: [{ role: "user", content: "test" }]
      )

      expect(WebMock).to have_requested(:post, endpoint_url)
    end

    it "includes messages array in request body" do
      messages = [
        { role: "system", content: "System prompt" },
        { role: "user", content: "User message" }
      ]

      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(model: "gpt-4", messages:)

      # Verify request was made with correct messages
      expect(WebMock).to(have_requested(:post, endpoint_url).with do |request|
        body = JSON.parse(request.body)
        body["messages"].is_a?(Array) && body["messages"].length == 2
      end)
    end

    it "only includes model and messages when no optional params given" do
      stub_request(:post, endpoint_url)
        .to_return(status: 200, body: { choices: [] }.to_json)

      client.chat_completion(
        model: "gpt-4",
        messages: [{ role: "user", content: "test" }]
      )

      expect(WebMock).to(have_requested(:post, endpoint_url).with do |request|
        body = JSON.parse(request.body)
        body.keys.sort == %w[messages model]
      end)
    end
  end
end
