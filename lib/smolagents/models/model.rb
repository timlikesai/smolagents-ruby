require_relative "model/configuration"
require_relative "model/generation"
require_relative "model/tool_parsing"
require_relative "model/callable"
require_relative "model/validation"

module Smolagents
  module Models
    # Abstract base class for all LLM model implementations.
    #
    # Model provides the interface contract for generating text responses from
    # language models. Concrete implementations (OpenAIModel, AnthropicModel,
    # LiteLLMModel) handle provider-specific API interactions.
    #
    # All models support:
    # - Message-based chat completion
    # - Optional streaming responses
    # - Tool/function calling
    # - Token usage tracking
    #
    # @example Subclassing Model
    #   class MyCustomModel < Model
    #     def generate(messages, **options)
    #       # Call your API here
    #       ChatMessage.assistant(response_text)
    #     end
    #   end
    #
    # @example Using with ModelBuilder DSL (local model)
    #   model = Smolagents.model(:lm_studio)
    #     .id("gemma-3n-e4b-it-q8_0")
    #     .temperature(0.7)
    #     .build
    #
    # @example Using with cloud provider
    #   model = Smolagents.model(:anthropic)
    #     .id("claude-sonnet-4-5-20251101")
    #     .api_key(ENV["ANTHROPIC_API_KEY"])
    #     .build
    #
    # @abstract Subclass and implement {#generate} to create a custom model.
    # @see OpenAIModel For OpenAI-compatible APIs (including local servers)
    # @see AnthropicModel For Anthropic Claude 4.5 APIs
    # @see LiteLLMModel For multi-provider support
    class Model
      include Configuration
      include Generation
      include ToolParsing
      include Callable
      include Validation

      # Creates a new model instance.
      #
      # Supports two initialization patterns:
      # 1. Config-based: Pass a ModelConfig object via the config: parameter
      # 2. Keyword-based: Pass individual parameters (model_id:, api_key:, etc.)
      #
      # @param model_id [String] The model identifier
      # @param config [Types::ModelConfig, nil] Unified configuration object
      # @param api_key [String, nil] API key for authentication
      # @param api_base [String, nil] Custom API endpoint URL
      # @param temperature [Float] Sampling temperature (default: 0.7)
      # @param max_tokens [Integer, nil] Maximum tokens in response
      # @param kwargs [Hash] Additional provider-specific options
      #
      # @see Types::ModelConfig
      def initialize(model_id: nil, config: nil, api_key: nil, api_base: nil,
                     temperature: 0.7, max_tokens: nil, **)
        initialize_configuration(model_id:, config:, api_key:, api_base:, temperature:, max_tokens:, **)
      end
    end
  end
end
