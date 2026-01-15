require_relative "anthropic/message_formatter"
require_relative "anthropic/request_builder"
require_relative "anthropic/response_parser"
require_relative "anthropic/streaming"

module Smolagents
  module Models
    # Model implementation for Anthropic's Claude API.
    #
    # Supports chat completion, tool calling, vision, and streaming.
    # Automatically handles system message extraction (Anthropic uses separate param).
    #
    # @example Basic usage
    #   model = AnthropicModel.new(
    #     model_id: "claude-opus-4-5-20251101",
    #     api_key: ENV["ANTHROPIC_API_KEY"]
    #   )
    #   response = model.generate([ChatMessage.user("Hello!")])
    #
    # @example With ModelBuilder DSL
    #   model = Smolagents.model(:anthropic)
    #     .id("claude-sonnet-4-5-20251101")
    #     .temperature(0.5)
    #     .build
    class AnthropicModel < Model
      include Concerns::GemLoader
      include Concerns::Api
      include Concerns::ToolSchema
      include Concerns::MessageFormatting
      include Anthropic::MessageFormatter
      include Anthropic::RequestBuilder
      include Anthropic::ResponseParser
      include Anthropic::Streaming

      DEFAULT_MAX_TOKENS = 4096

      # @param model_id [String] Claude model identifier
      # @param api_key [String, nil] Anthropic API key (defaults to ANTHROPIC_API_KEY env)
      # @param temperature [Float] Sampling temperature (0.0-1.0)
      # @param max_tokens [Integer] Maximum response tokens (required by Anthropic)
      # @param client [Anthropic::Client, nil] Pre-configured client for DI
      def initialize(model_id:, api_key: nil, temperature: 0.7, max_tokens: DEFAULT_MAX_TOKENS, client: nil, **)
        require_gem "anthropic", install_name: "ruby-anthropic", version: "~> 0.4",
                                 description: "ruby-anthropic gem required for Anthropic models"
        super(model_id:, **)
        @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
        @temperature = temperature
        @max_tokens = max_tokens
        @client = client || ::Anthropic::Client.new(access_token: @api_key)
      end

      # Generate a response from Claude API.
      #
      # @param messages [Array<ChatMessage>] Conversation history
      # @param stop_sequences [Array<String>, nil] Stop sequences
      # @param temperature [Float, nil] Override temperature
      # @param max_tokens [Integer, nil] Override max tokens
      # @param tools_to_call_from [Array<Tool>, nil] Available tools
      # @param response_format [Hash, nil] Not supported (emits warning)
      # @return [ChatMessage] Assistant response with optional tool_calls
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil,
                   tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
          warn "[AnthropicModel] response_format is not supported by Anthropic API" if response_format
          params = build_params(messages, stop_sequences, temperature, max_tokens, tools_to_call_from)
          response = api_call(service: "anthropic", operation: "messages",
                              retryable_errors: [Faraday::Error, ::Anthropic::Error]) do
            @client.messages(parameters: params)
          end
          parse_response(response)
        end
      end

      # Generate streaming response from Claude API.
      #
      # @param messages [Array<ChatMessage>] Conversation history
      # @yield [ChatMessage] Each streaming chunk
      # @return [Enumerator<ChatMessage>] When no block given
      def generate_stream(messages, **, &)
        return enum_for(:generate_stream, messages, **) unless block_given?

        params = build_stream_params(messages)
        with_circuit_breaker("anthropic_api") { stream_messages(params, &) }
      end
    end
  end
end
