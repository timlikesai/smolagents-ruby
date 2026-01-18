module Smolagents
  module Models
    module OpenAI
      # Factory methods for cloud API providers using OpenAI-compatible APIs.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for cloud providers that implement the OpenAI API spec.
      #
      # Supported providers:
      # - **OpenRouter**: Unified API for 100+ models (Claude, Gemini, Llama, etc.)
      # - **Together AI**: Fast inference for open-source models
      # - **Groq**: Ultra-fast inference using custom LPU hardware
      # - **Fireworks AI**: High-performance model serving
      # - **DeepInfra**: Cost-effective inference at scale
      #
      # @example OpenRouter (recommended for multi-model access)
      #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
      #
      # @example Together AI (fast open-source models)
      #   model = OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")
      #
      # @example Groq (ultra-fast inference)
      #   model = OpenAIModel.groq("llama-3.3-70b-versatile")
      #
      # @see LocalServers For local inference server factory methods
      module CloudProviders
        # @return [Hash{Symbol => Hash}] Provider configurations.
        PROVIDERS = {
          openrouter: { endpoint: "https://openrouter.ai/api/v1", env_var: "OPENROUTER_API_KEY" },
          together: { endpoint: "https://api.together.xyz/v1", env_var: "TOGETHER_API_KEY" },
          groq: { endpoint: "https://api.groq.com/openai/v1", env_var: "GROQ_API_KEY" },
          fireworks: { endpoint: "https://api.fireworks.ai/inference/v1", env_var: "FIREWORKS_API_KEY" },
          deepinfra: { endpoint: "https://api.deepinfra.com/v1/openai", env_var: "DEEPINFRA_API_KEY" }
        }.freeze

        # Legacy accessors for backwards compatibility.
        ENDPOINTS = PROVIDERS.transform_values { |v| v[:endpoint] }.freeze
        API_KEY_ENV_VARS = PROVIDERS.transform_values { |v| v[:env_var] }.freeze

        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for cloud provider factory methods.
        # Generated dynamically from PROVIDERS configuration.
        module ClassMethods
          CloudProviders::PROVIDERS.each do |provider, config|
            # Defines a factory method for each provider.
            #
            # @param model_id [String] Model identifier
            # @param api_key [String, nil] API key (falls back to env var)
            # @param options [Hash] Additional options passed to OpenAIModel
            # @return [OpenAIModel] Configured model instance
            define_method(provider) do |model_id, api_key: nil, **options|
              key = api_key || ENV.fetch(config[:env_var], nil)
              new(model_id:, api_base: config[:endpoint], api_key: key, **options)
            end
          end
        end
      end
    end
  end
end
