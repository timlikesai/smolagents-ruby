require "net/http"
require "json"
require "uri"

module Smolagents
  module Http
    # Ractor-safe HTTP client for OpenAI-compatible APIs.
    #
    # Uses Net::HTTP directly without any global state, making it safe
    # to use inside Ractors where gems like ruby-openai fail due to
    # global configuration access.
    #
    # @example Making a chat completion request
    #   client = RactorSafeClient.new(
    #     api_base: "http://localhost:1234/v1",
    #     api_key: "test-key"
    #   )
    #   response = client.chat_completion(
    #     model: "gpt-4",
    #     messages: [{ role: "user", content: "Hello" }]
    #   )
    class RactorSafeClient
      DEFAULT_TIMEOUT = 120

      attr_reader :api_base, :timeout

      def initialize(api_base:, api_key:, timeout: DEFAULT_TIMEOUT)
        @api_base = api_base.chomp("/")
        @api_key = api_key
        @timeout = timeout
      end

      # Make a chat completion request.
      #
      # @param model [String] Model ID
      # @param messages [Array<Hash>] Chat messages
      # @param temperature [Float, nil] Sampling temperature
      # @param max_tokens [Integer, nil] Maximum tokens to generate
      # @param tools [Array<Hash>, nil] Tool definitions
      # @param stop [Array<String>, nil] Stop sequences
      # @return [Hash] Parsed JSON response
      def chat_completion(model:, messages:, temperature: nil, max_tokens: nil, tools: nil, stop: nil)
        body = {
          model: model,
          messages: messages,
          temperature: temperature,
          max_tokens: max_tokens,
          tools: tools,
          stop: stop
        }.compact

        post("/chat/completions", body)
      end

      private

      def post(path, body)
        uri = URI("#{@api_base}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}" if @api_key
        request.body = JSON.generate(body)

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        else
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
end
