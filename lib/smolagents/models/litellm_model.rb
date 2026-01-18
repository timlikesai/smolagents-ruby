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

      # Initializes a LiteLLMModel with automatic provider detection.
      #
      # Parses the model_id to detect the provider and creates the appropriate backend model.
      # Supports both config-based and keyword-based initialization.
      #
      # @param model_id [String] Model identifier with optional provider prefix (e.g., "anthropic/claude-3")
      # @param config [Types::ModelConfig, nil] Unified configuration object
      # @param api_key [String, nil] API key for the provider
      # @param api_base [String, nil] Custom API endpoint URL
      # @param temperature [Float] Sampling temperature (default: 0.7)
      # @param max_tokens [Integer, nil] Maximum tokens in response
      # @param kwargs [Hash] Provider-specific options passed to backend
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
      # Routes the request to the appropriate backend implementation (OpenAI, Anthropic, etc.).
      #
      # @param args [Array] Arguments passed to backend#generate
      # @param kwargs [Hash] Keyword arguments passed to backend#generate
      # @return [ChatMessage] The assistant's response from the backend
      #
      # @see Model#generate Base class definition
      def generate(...)
        @backend.generate(...)
      end

      # Generates a streaming response by delegating to the backend model.
      #
      # Routes streaming requests to the appropriate backend implementation.
      #
      # @param args [Array] Arguments passed to backend#generate_stream
      # @param kwargs [Hash] Keyword arguments passed to backend#generate_stream
      # @yield [ChatMessage] Each streaming chunk from the backend
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
