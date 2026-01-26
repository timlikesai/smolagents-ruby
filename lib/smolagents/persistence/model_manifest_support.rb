module Smolagents
  module Persistence
    # Constants and detection helpers for model manifest serialization.
    module ModelManifestSupport
      # Instance variable names that are never serialized (sensitive credentials)
      SENSITIVE_KEYS = %i[api_key access_token auth_token bearer_token password secret
                          credential api_secret private_key].freeze

      # Instance variable names excluded from serialization (non-serializable objects)
      NON_SERIALIZABLE_KEYS = %i[client logger model_id kwargs].freeze

      # Model classes allowed to be loaded from manifests (security allowlist)
      ALLOWED_CLASSES = Set.new(%w[
                                  Smolagents::OpenAIModel
                                  Smolagents::AnthropicModel
                                  Smolagents::LiteLLMModel
                                ]).freeze

      # Providers that don't require API keys (local servers)
      LOCAL_PROVIDERS = %i[lm_studio ollama llama_cpp mlx_lm vllm text_generation_webui].freeze

      # Provider to environment variable mapping
      ENV_KEYS = { openai: "OPENAI_API_KEY", anthropic: "ANTHROPIC_API_KEY",
                   azure: "AZURE_OPENAI_API_KEY", gemini: "GOOGLE_API_KEY" }.freeze

      # Local provider to factory method mapping
      PROVIDER_METHODS = { lm_studio: :lm_studio, ollama: :ollama, llama_cpp: :llama_cpp,
                           vllm: :vllm, mlx_lm: :mlx_lm }.freeze

      module_function

      # Detects provider from model and config
      def detect_provider(model, config)
        return config[:provider].to_sym if config[:provider]

        api_base = config[:api_base] || config[:uri_base]
        return detect_from_url(api_base) if api_base

        detect_from_class(model)
      end

      # Detects provider from API base URL patterns
      def detect_from_url(url)
        case url
        when /localhost:1234/, /lm.studio/i then :lm_studio
        when /localhost:11434/, /ollama/i then :ollama
        when /localhost:8080/ then :llama_cpp
        when /localhost:8000/, /vllm/i then :vllm
        when /azure\.com/i then :azure
        else :openai
        end
      end

      # Detects provider from model class name
      def detect_from_class(model)
        case model.class.name
        when "Smolagents::AnthropicModel" then :anthropic
        when "Smolagents::LiteLLMModel" then detect_litellm_provider(model)
        else :openai
        end
      end

      # Detects provider for LiteLLM models
      def detect_litellm_provider(model)
        return :openai unless model.respond_to?(:provider)

        model.provider&.to_sym || :openai
      end
    end
  end
end
