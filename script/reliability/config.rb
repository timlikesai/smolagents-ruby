# Reliability test configuration
# API endpoints and model mappings for testing

module Reliability
  module Config
    # API Providers
    PROVIDERS = {
      "llama-cpp" => {
        name: "llama.cpp (Mac Studio)",
        api_base: "https://llama-cpp-ultra.reverse-bull.ts.net/v1",
        api_key: "not-needed",
        supports_reasoning_content: false
      },
      "lm-studio" => {
        name: "LM Studio (MacBook Pro M4)",
        api_base: "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1",
        api_key: "lm-studio",
        supports_reasoning_content: true # Has separated reasoning content block
      }
    }.freeze

    # Models by provider
    MODELS = {
      "llama-cpp" => {
        # Reasoning models (4-bit quants)
        "glm-q4" => "GLM-4.7-Flash-Q4_1",
        "glm-mxfp4" => "GLM-4.7-Flash-MXFP4_MOE",
        "nemotron-q4" => "Nemotron-3-Nano-30B-A3B-Q4_1",
        "nemotron-mxfp4" => "NVIDIA-Nemotron-3-Nano-30B-A3B-MXFP4_MOE",
        # Other models
        "lfm" => "LFM2.5-1.2B-Instruct-Q8_0",
        "gemma" => "gemma-3n-E4B-it-Q8_0",
        "gpt-oss" => "gpt-oss-20b-preview-2025-01-22-Q4_0"
      },
      "lm-studio" => {
        # 8-bit quants (MLX)
        "glm-q8" => "glm-4.7-flash-mlx@8bit",
        "nemotron-q8" => "mlx-community/nvidia-nemotron-3-nano-30b-a3b-mlx",
        "nemotron-mxfp4" => "nemotron-3-nano",
        "lfm" => "lfm2.5-1.2b-instruct-mlx@8bit"
      }
    }.freeze

    # Default provider and model
    DEFAULT_PROVIDER = "llama-cpp".freeze
    DEFAULT_MODEL = "lfm".freeze

    class << self
      def provider(name)
        PROVIDERS[name] || raise("Unknown provider: #{name}. Available: #{PROVIDERS.keys.join(", ")}")
      end

      def model_id(provider_name, model_alias)
        models = MODELS[provider_name] || raise("Unknown provider: #{provider_name}")
        # Allow full model ID or alias
        models[model_alias] || model_alias
      end

      def list_providers
        PROVIDERS.map { |k, v| "  #{k}: #{v[:name]}" }.join("\n")
      end

      def list_models(provider_name)
        models = MODELS[provider_name] || {}
        models.map { |alias_name, full_id| "  #{alias_name} => #{full_id}" }.join("\n")
      end

      def resolve(provider_name, model_alias)
        prov = provider(provider_name)
        model = model_id(provider_name, model_alias)
        {
          api_base: prov[:api_base],
          api_key: prov[:api_key],
          model_id: model,
          supports_reasoning_content: prov[:supports_reasoning_content]
        }
      end
    end
  end
end
