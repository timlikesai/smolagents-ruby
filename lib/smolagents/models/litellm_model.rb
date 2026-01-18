require_relative "litellm_model/provider_routing"
require_relative "litellm_model/backend_factory"

module Smolagents
  module Models
    # Multi-provider model router using "provider/model" format.
    #
    # Providers: openai (default), anthropic, azure, ollama, lm_studio, llama_cpp, mlx_lm, vllm
    #
    # @example model = LiteLLMModel.new(model_id: "lm_studio/gemma-3n-e4b-it-q8_0")
    # @see Model Base class
    # @see ProviderRouting Provider detection
    # @see BackendFactory Backend creation
    class LiteLLMModel < Model
      include LiteLLM::ProviderRouting
      include LiteLLM::BackendFactory

      # @!attribute [r] provider
      #   @return [String] The detected provider name from the model_id prefix.
      attr_reader :provider

      # @!attribute [r] backend
      #   @return [Model] The backend model instance that handles API communication.
      attr_reader :backend

      # @param model_id [String] Model identifier with optional provider prefix
      # @param kwargs [Hash] Provider-specific options (api_key, api_base, temperature, max_tokens)
      def initialize(model_id: nil, config: nil, api_key: nil, api_base: nil,
                     temperature: 0.7, max_tokens: nil, **)
        super
        @provider, @resolved_model = parse_model_id(@model_id)
        @backend = create_backend(
          @provider, @resolved_model,
          api_key: @api_key, api_base: @api_base,
          temperature: @temperature, max_tokens: @max_tokens, **@kwargs
        )
      end

      # Generates a response by delegating to the backend model.
      #
      # @param args [Array] Arguments passed to backend#generate
      # @return [ChatMessage] The assistant's response
      #
      # @see Model#generate Base class definition
      def generate(...)
        @backend.generate(...)
      end

      # Generates a streaming response by delegating to the backend model.
      #
      # @param args [Array] Arguments passed to backend#generate_stream
      # @yield [ChatMessage] Each streaming chunk
      # @return [Enumerator<ChatMessage>] When no block given
      #
      # @see Model#generate_stream Base class definition
      def generate_stream(...)
        @backend.generate_stream(...)
      end

      # For backwards compatibility - expose PROVIDERS from routing module
      PROVIDERS = LiteLLM::ProviderRouting::PROVIDERS
      PROVIDER_METHODS = LiteLLM::ProviderRouting::LOCAL_SERVERS
    end
  end
end
