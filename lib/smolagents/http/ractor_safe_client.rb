require "net/http"
require "json"
require "uri"

module Smolagents
  module Http
    # Ractor-safe HTTP client for OpenAI-compatible APIs.
    #
    # Implements a minimal OpenAI-compatible API client using only Net::HTTP.
    # Avoids all global state, making it safe to use inside Ractors where
    # other HTTP gems (ruby-openai, httparty, etc.) fail due to thread-local
    # or global configuration access.
    #
    # Suitable for:
    # - Ractor-based concurrent execution
    # - Thread-safe operations
    # - Minimal dependencies
    # - OpenAI, Anthropic (via OpenRouter), LiteLLM, and local model APIs
    #
    # Note: This is a minimal client focused on chat completions. For full
    # OpenAI API support, use a full-featured client outside Ractors.
    #
    # @example Making a chat completion request to local model
    #   client = RactorSafeClient.new(
    #     api_base: "http://localhost:1234/v1",
    #     api_key: "not-needed"
    #   )
    #   response = client.chat_completion(
    #     model: "gpt-4",
    #     messages: [
    #       { role: "system", content: "You are helpful" },
    #       { role: "user", content: "Hello!" }
    #     ]
    #   )
    #
    # @example Using with tool definitions
    #   response = client.chat_completion(
    #     model: "gpt-4",
    #     messages: [...],
    #     tools: [
    #       { type: "function", function: { name: "search", ... } }
    #     ]
    #   )
    #
    # @see Http::UserAgent For RFC 7231 compliant User-Agent strings
    #
    class RactorSafeClient
      # Default HTTP timeout in seconds (2 minutes)
      DEFAULT_TIMEOUT = 120

      # @return [String] The API base URL (without trailing slash)
      attr_reader :api_base

      # @return [Integer] The HTTP timeout in seconds
      attr_reader :timeout

      # Creates a new Ractor-safe HTTP client.
      #
      # @param api_base [String] The API base URL (e.g., "http://localhost:1234/v1")
      # @param api_key [String] API key for authentication (empty string if not needed)
      # @param timeout [Integer] Request timeout in seconds (default: 120)
      #
      # @example
      #   client = RactorSafeClient.new(
      #     api_base: "https://api.openai.com/v1",
      #     api_key: ENV["OPENAI_API_KEY"]
      #   )
      def initialize(api_base:, api_key:, timeout: DEFAULT_TIMEOUT)
        @api_base = api_base.chomp("/")
        @api_key = api_key
        @timeout = timeout
      end

      # Makes a chat completion request to the API.
      #
      # Sends a JSON request to the /chat/completions endpoint and returns
      # the parsed JSON response. Handles both success and error responses.
      #
      # @param model [String] Model identifier (e.g., "gpt-4")
      # @param messages [Array<Hash>] Array of message objects with role and content
      #   - Must include role: "user", "assistant", or "system"
      #   - Must include content: [String] the message text
      # @param temperature [Float, nil] Sampling temperature (0.0-2.0), default nil
      # @param max_tokens [Integer, nil] Maximum response length, default nil
      # @param tools [Array<Hash>, nil] Tool/function definitions, default nil
      # @param stop [Array<String>, nil] Stop sequences, default nil
      # @return [Hash] Parsed JSON response from the API
      #   - Success: { "choices" => [...], "usage" => {...} }
      #   - Error: { "error" => { "message" => "..." } }
      #
      # @example Minimal request
      #   client.chat_completion(
      #     model: "llama2",
      #     messages: [{ role: "user", content: "Hello" }]
      #   )
      #
      # @example Full-featured request
      #   client.chat_completion(
      #     model: "gpt-4",
      #     messages: [
      #       { role: "system", content: "Be concise" },
      #       { role: "user", content: "Explain AI" }
      #     ],
      #     temperature: 0.7,
      #     max_tokens: 100,
      #     stop: ["\n\n"]
      #   )
      def chat_completion(model:, messages:, temperature: nil, max_tokens: nil, tools: nil, stop: nil)
        body = {
          model:,
          messages:,
          temperature:,
          max_tokens:,
          tools:,
          stop:
        }.compact

        post("/chat/completions", body)
      end

      private

      def post(path, body)
        uri = URI("#{@api_base}#{path}")
        response = build_http(uri).request(build_request(uri, body))
        parse_response(response)
      end

      def build_http(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = @timeout
          http.read_timeout = @timeout
        end
      end

      def build_request(uri, body)
        Net::HTTP::Post.new(uri.request_uri).tap do |req|
          req["Content-Type"] = "application/json"
          req["Authorization"] = "Bearer #{@api_key}" if @api_key
          req.body = JSON.generate(body)
        end
      end

      def parse_response(response)
        return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

        error_body = begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          { "error" => { "message" => response.body } }
        end
        error_body["error"] ||= { "message" => "HTTP #{response.code}: #{response.message}" }
        error_body
      end
    end
  end
end
