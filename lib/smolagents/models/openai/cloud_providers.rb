module Smolagents
  module Models
    module OpenAI
      # Factory methods for cloud API providers using OpenAI-compatible APIs.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for cloud providers that implement the OpenAI API spec.
      #
      # @example OpenRouter with any model
      #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
      #   model = OpenAIModel.openrouter("google/gemini-2.5-flash")
      #
      # @example Together AI
      #   model = OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")
      #
      # @example Groq
      #   model = OpenAIModel.groq("llama-3.3-70b-versatile")
      #
      # @see https://openrouter.ai/docs OpenRouter Documentation
      # @see https://docs.together.ai Together AI Documentation
      # @see https://console.groq.com/docs Groq Documentation
      # @see https://docs.fireworks.ai Fireworks AI Documentation
      # @see https://deepinfra.com/docs DeepInfra Documentation
      module CloudProviders
        # API base URLs for cloud providers.
        # @see https://openrouter.ai/docs/quickstart OpenRouter Quickstart
        # @see https://console.groq.com/docs/openai Groq OpenAI Compatibility
        # @see https://docs.together.ai/docs/quickstart Together AI Quickstart
        # @see https://docs.fireworks.ai/tools-sdks/openai-compatibility Fireworks OpenAI Compatibility
        # @see https://deepinfra.com/docs/openai_api DeepInfra OpenAI API
        ENDPOINTS = {
          openrouter: "https://openrouter.ai/api/v1",
          together: "https://api.together.xyz/v1",
          groq: "https://api.groq.com/openai/v1",
          fireworks: "https://api.fireworks.ai/inference/v1",
          deepinfra: "https://api.deepinfra.com/v1/openai"
        }.freeze

        # Environment variable names for API keys.
        API_KEY_ENV_VARS = {
          openrouter: "OPENROUTER_API_KEY",
          together: "TOGETHER_API_KEY",
          groq: "GROQ_API_KEY",
          fireworks: "FIREWORKS_API_KEY",
          deepinfra: "DEEPINFRA_API_KEY"
        }.freeze

        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for cloud provider factory methods.
        module ClassMethods
          # Creates model for OpenRouter (access to 100+ models).
          #
          # OpenRouter provides a unified API to access models from OpenAI,
          # Anthropic, Google, Meta, and many others through a single endpoint.
          #
          # @param model_id [String] Model identifier in "provider/model" format
          # @param api_key [String, nil] API key (defaults to OPENROUTER_API_KEY env var)
          # @param kwargs [Hash] Additional options passed to OpenAIModel
          # @return [OpenAIModel]
          #
          # @example Claude via OpenRouter
          #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
          #
          # @example Gemini via OpenRouter
          #   model = OpenAIModel.openrouter("google/gemini-2.5-flash")
          #
          # @see https://openrouter.ai/docs OpenRouter Documentation
          # @see https://openrouter.ai/models Available Models
          def openrouter(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:openrouter], nil)
            new(model_id:, api_base: ENDPOINTS[:openrouter], api_key: key, **)
          end

          # Creates model for Together AI.
          #
          # @param model_id [String] Model identifier
          # @param api_key [String, nil] API key (defaults to TOGETHER_API_KEY env var)
          # @param kwargs [Hash] Additional options
          # @return [OpenAIModel]
          #
          # @example Llama 3.3 (recommended)
          #   model = OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")
          #
          # @example DeepSeek
          #   model = OpenAIModel.together("deepseek-ai/DeepSeek-V3")
          #
          # @see https://docs.together.ai Together AI Documentation
          # @see https://docs.together.ai/docs/serverless-models Available Models
          def together(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:together], nil)
            new(model_id:, api_base: ENDPOINTS[:together], api_key: key, **)
          end

          # Creates model for Groq (fast inference).
          #
          # @param model_id [String] Model identifier
          # @param api_key [String, nil] API key (defaults to GROQ_API_KEY env var)
          # @param kwargs [Hash] Additional options
          # @return [OpenAIModel]
          #
          # @example Llama 3.3 70B
          #   model = OpenAIModel.groq("llama-3.3-70b-versatile")
          #
          # @example Llama 3.1 8B (faster)
          #   model = OpenAIModel.groq("llama-3.1-8b-instant")
          #
          # @see https://console.groq.com/docs Groq Documentation
          # @see https://console.groq.com/docs/models Available Models
          def groq(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:groq], nil)
            new(model_id:, api_base: ENDPOINTS[:groq], api_key: key, **)
          end

          # Creates model for Fireworks AI.
          #
          # @param model_id [String] Model identifier (use full path format)
          # @param api_key [String, nil] API key (defaults to FIREWORKS_API_KEY env var)
          # @param kwargs [Hash] Additional options
          # @return [OpenAIModel]
          #
          # @example Llama 3 70B
          #   model = OpenAIModel.fireworks("accounts/fireworks/models/llama-v3-70b-instruct")
          #
          # @example Mixtral
          #   model = OpenAIModel.fireworks("accounts/fireworks/models/mixtral-8x7b-instruct")
          #
          # @see https://docs.fireworks.ai Fireworks AI Documentation
          # @see https://docs.fireworks.ai/getting-started/models Available Models
          def fireworks(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:fireworks], nil)
            new(model_id:, api_base: ENDPOINTS[:fireworks], api_key: key, **)
          end

          # Creates model for DeepInfra.
          #
          # @param model_id [String] Model identifier
          # @param api_key [String, nil] API key (defaults to DEEPINFRA_API_KEY env var)
          # @param kwargs [Hash] Additional options
          # @return [OpenAIModel]
          #
          # @example Llama 3.1 70B
          #   model = OpenAIModel.deepinfra("meta-llama/Meta-Llama-3.1-70B-Instruct")
          #
          # @example Mistral
          #   model = OpenAIModel.deepinfra("mistralai/Mixtral-8x7B-Instruct-v0.1")
          #
          # @see https://deepinfra.com/docs DeepInfra Documentation
          # @see https://deepinfra.com/models Available Models
          def deepinfra(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:deepinfra], nil)
            new(model_id:, api_base: ENDPOINTS[:deepinfra], api_key: key, **)
          end
        end
      end
    end
  end
end
