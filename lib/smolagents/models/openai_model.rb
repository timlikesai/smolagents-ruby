require_relative "openai/cloud_providers"
require_relative "openai/local_servers"
require_relative "openai/request_builder"
require_relative "openai/response_parser"
require_relative "openai/message_formatter"

module Smolagents
  module Models
    # Model implementation for OpenAI and OpenAI-compatible APIs.
    #
    # Supports cloud OpenAI, cloud providers (OpenRouter, Together, Groq),
    # Azure OpenAI, and local servers (LM Studio, Ollama, llama.cpp, vLLM).
    #
    # @example Local model with LM Studio
    #   model = OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
    #
    # @example Cloud OpenAI
    #   model = OpenAIModel.new(model_id: "gpt-4-turbo")
    #
    # @example OpenRouter (100+ models via one API)
    #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
    #
    # @see Model Base class documentation
    class OpenAIModel < Model
      include Concerns::GemLoader
      include Concerns::Api
      include Concerns::ToolSchema
      include OpenAI::CloudProviders
      include OpenAI::LocalServers
      include OpenAI::RequestBuilder
      include OpenAI::ResponseParser
      include OpenAI::MessageFormatter

      # @param model_id [String] Model identifier
      # @param api_key [String, nil] API key (defaults to OPENAI_API_KEY env var)
      # @param api_base [String, nil] Base URL for API endpoint
      # @param temperature [Float] Sampling temperature (default: 0.7)
      # @param max_tokens [Integer, nil] Max tokens in response
      # @param azure_api_version [String, nil] Azure API version
      # @param client [OpenAI::Client, nil] Pre-configured client
      # @param kwargs [Hash] Additional options passed to parent
      def initialize(model_id:, api_key: nil, api_base: nil, temperature: 0.7,
                     max_tokens: nil, azure_api_version: nil, client: nil, **kwargs)
        require_gem "openai", install_name: "ruby-openai", version: "~> 7.0",
                              description: "ruby-openai gem required for OpenAI models"
        super(model_id:, **kwargs)
        @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
        @temperature = temperature
        @max_tokens = max_tokens
        @azure_api_version = azure_api_version
        @client = client || build_client(api_base, kwargs[:timeout])
      end

      # Generates a response from the OpenAI API.
      #
      # @param messages [Array<ChatMessage>] Conversation history
      # @param stop_sequences [Array<String>, nil] Stop sequences
      # @param temperature [Float, nil] Override temperature
      # @param max_tokens [Integer, nil] Override max tokens
      # @param tools_to_call_from [Array<Tool>, nil] Available tools
      # @param response_format [Hash, nil] Response format spec
      # @return [ChatMessage] Assistant response
      def generate(messages, stop_sequences: nil, temperature: nil, max_tokens: nil,
                   tools_to_call_from: nil, response_format: nil, **)
        Smolagents::Instrumentation.instrument("smolagents.model.generate", model_id:, model_class: self.class.name) do
          params = build_params(messages:, stop_sequences:, temperature:, max_tokens:,
                                tools: tools_to_call_from, response_format:)
          response = api_call(service: "openai", operation: "chat_completion",
                              retryable_errors: [Faraday::Error, ::OpenAI::Error]) do
            @client.chat(parameters: params)
          end
          parse_response(response)
        end
      end

      # Generates a streaming response.
      #
      # @param messages [Array<ChatMessage>] Conversation history
      # @yield [ChatMessage] Each streaming chunk
      # @return [Enumerator<ChatMessage>] When no block given
      def generate_stream(messages, **, &block)
        return enum_for(:generate_stream, messages, **) unless block

        params = { model: model_id, messages: format_messages(messages), temperature: @temperature, stream: true }
        with_circuit_breaker("openai_api") do
          @client.chat(parameters: params) { |chunk, _| yield_stream_chunk(chunk, &block) }
        end
      end

      private

      def yield_stream_chunk(chunk)
        delta = chunk.dig("choices", 0, "delta")
        return unless delta

        yield Smolagents::ChatMessage.assistant(delta["content"], tool_calls: delta["tool_calls"], raw: chunk)
      rescue StandardError
        nil
      end
    end
  end
end
