module Smolagents
  module Models
    module OpenAI
      # Factory methods for cloud API providers using OpenAI-compatible APIs.
      #
      # Provides convenient class methods to create OpenAIModel instances
      # pre-configured for cloud providers that implement the OpenAI API spec.
      # These providers typically offer faster inference, more models, or
      # better pricing than using OpenAI directly.
      #
      # Supported providers:
      # - **OpenRouter**: Unified API for 100+ models (Claude, Gemini, Llama, etc.)
      # - **Together AI**: Fast inference for open-source models
      # - **Groq**: Ultra-fast inference using custom LPU hardware
      # - **Fireworks AI**: High-performance model serving
      # - **DeepInfra**: Cost-effective inference at scale
      #
      # All providers use environment variables for API keys by default,
      # following the pattern `{PROVIDER}_API_KEY` (e.g., OPENROUTER_API_KEY).
      #
      # @example OpenRouter (recommended for multi-model access)
      #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
      #   model = OpenAIModel.openrouter("google/gemini-2.5-flash")
      #   # Access any model through one API key
      #
      # @example Together AI (fast open-source models)
      #   model = OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")
      #
      # @example Groq (ultra-fast inference)
      #   model = OpenAIModel.groq("llama-3.3-70b-versatile")
      #   # ~500 tokens/second for some models
      #
      # @see LocalServers For local inference server factory methods
      # @see OpenAIModel#initialize For direct instantiation
      # @see https://openrouter.ai/docs OpenRouter Documentation
      # @see https://docs.together.ai Together AI Documentation
      # @see https://console.groq.com/docs Groq Documentation
      # @see https://docs.fireworks.ai Fireworks AI Documentation
      # @see https://deepinfra.com/docs DeepInfra Documentation
      module CloudProviders
        # @return [Hash{Symbol => String}] API base URLs for cloud providers.
        #   Each provider has a specific endpoint that implements the OpenAI API spec.
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

        # @return [Hash{Symbol => String}] Environment variable names for API keys.
        #   Factory methods check these variables when api_key is not provided.
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
        #
        # These methods are extended onto OpenAIModel when CloudProviders is included,
        # providing convenient factory methods for creating models connected to
        # various cloud inference providers.
        module ClassMethods
          # Creates a model for OpenRouter (access to 100+ models).
          #
          # OpenRouter provides a unified API to access models from OpenAI,
          # Anthropic, Google, Meta, and many others through a single endpoint.
          # This is the recommended choice when you need access to multiple
          # model providers through a single API key.
          #
          # @param model_id [String] Model identifier in "provider/model" format
          #   (e.g., "anthropic/claude-3.5-sonnet", "google/gemini-2.5-flash")
          # @param api_key [String, nil] OpenRouter API key. Falls back to
          #   OPENROUTER_API_KEY environment variable if not provided.
          # @param options [Hash] Additional options passed to OpenAIModel
          # @option options [Float] :temperature Sampling temperature (0.0-2.0)
          # @option options [Integer] :max_tokens Maximum response tokens
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Claude via OpenRouter
          #   model = OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
          #   response = model.generate([ChatMessage.user("Hello!")])
          #
          # @example Gemini via OpenRouter
          #   model = OpenAIModel.openrouter("google/gemini-2.5-flash")
          #
          # @example With explicit API key
          #   model = OpenAIModel.openrouter("meta-llama/llama-3-70b",
          #     api_key: "sk-or-...",
          #     temperature: 0.7
          #   )
          #
          # @see https://openrouter.ai/docs OpenRouter Documentation
          # @see https://openrouter.ai/models Available Models
          def openrouter(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:openrouter], nil)
            new(model_id:, api_base: ENDPOINTS[:openrouter], api_key: key, **)
          end

          # Creates a model for Together AI.
          #
          # Together AI provides fast inference for popular open-source models
          # with competitive pricing. Good choice for production deployments
          # of Llama, Mistral, and other open models.
          #
          # @param model_id [String] Model identifier (Hugging Face format)
          #   (e.g., "meta-llama/Llama-3.3-70B-Instruct-Turbo")
          # @param api_key [String, nil] Together AI API key. Falls back to
          #   TOGETHER_API_KEY environment variable if not provided.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
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

          # Creates a model for Groq (ultra-fast inference).
          #
          # Groq uses custom LPU (Language Processing Unit) hardware to achieve
          # extremely fast inference speeds, often 10x faster than GPU-based
          # inference. Ideal for latency-sensitive applications.
          #
          # @param model_id [String] Model identifier using Groq's naming
          #   (e.g., "llama-3.3-70b-versatile", "mixtral-8x7b-32768")
          # @param api_key [String, nil] Groq API key. Falls back to
          #   GROQ_API_KEY environment variable if not provided.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
          #
          # @example Llama 3.3 70B (most capable)
          #   model = OpenAIModel.groq("llama-3.3-70b-versatile")
          #
          # @example Llama 3.1 8B (fastest)
          #   model = OpenAIModel.groq("llama-3.1-8b-instant")
          #
          # @see https://console.groq.com/docs Groq Documentation
          # @see https://console.groq.com/docs/models Available Models
          def groq(model_id, api_key: nil, **)
            key = api_key || ENV.fetch(API_KEY_ENV_VARS[:groq], nil)
            new(model_id:, api_base: ENDPOINTS[:groq], api_key: key, **)
          end

          # Creates a model for Fireworks AI.
          #
          # Fireworks AI provides high-performance model serving with competitive
          # pricing. Good choice for production workloads requiring reliability
          # and consistent latency.
          #
          # @param model_id [String] Model identifier in Fireworks format
          #   (e.g., "accounts/fireworks/models/llama-v3-70b-instruct")
          # @param api_key [String, nil] Fireworks API key. Falls back to
          #   FIREWORKS_API_KEY environment variable if not provided.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
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

          # Creates a model for DeepInfra.
          #
          # DeepInfra provides cost-effective inference at scale with pay-per-token
          # pricing. Good choice for high-volume applications where cost is a
          # primary concern.
          #
          # @param model_id [String] Model identifier (Hugging Face format)
          #   (e.g., "meta-llama/Meta-Llama-3.1-70B-Instruct")
          # @param api_key [String, nil] DeepInfra API key. Falls back to
          #   DEEPINFRA_API_KEY environment variable if not provided.
          # @param options [Hash] Additional options passed to OpenAIModel
          #
          # @return [OpenAIModel] Configured model instance
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
