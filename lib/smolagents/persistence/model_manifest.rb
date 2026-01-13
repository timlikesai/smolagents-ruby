module Smolagents
  module Persistence
    # @return [Array<Symbol>] Instance variable names that are never serialized.
    #   These contain sensitive credentials like API keys.
    MODEL_SENSITIVE_KEYS = %i[api_key access_token auth_token bearer_token password secret
                              credential api_secret private_key].freeze

    # @return [Array<Symbol>] Instance variable names excluded from serialization
    #   because they contain non-serializable objects (HTTP clients, loggers).
    MODEL_NON_SERIALIZABLE = %i[client logger model_id kwargs].freeze

    # @return [Set<String>] Model classes allowed to be loaded from manifests.
    #   Prevents arbitrary code execution via malicious manifests.
    ALLOWED_MODEL_CLASSES = Set.new(%w[
                                      Smolagents::OpenAIModel
                                      Smolagents::AnthropicModel
                                      Smolagents::LiteLLMModel
                                    ]).freeze

    # @return [Array<Symbol>] Providers that don't require API keys (local servers)
    LOCAL_PROVIDERS = %i[lm_studio ollama llama_cpp mlx_lm vllm text_generation_webui].freeze

    # @return [Hash{Symbol => String}] Provider to environment variable mapping
    PROVIDER_ENV_KEYS = {
      openai: "OPENAI_API_KEY",
      anthropic: "ANTHROPIC_API_KEY",
      azure: "AZURE_OPENAI_API_KEY",
      gemini: "GOOGLE_API_KEY"
    }.freeze

    # Immutable manifest describing a model's configuration.
    #
    # ModelManifest captures the information needed to reconstruct a model,
    # except for API keys and other sensitive data which are never serialized.
    # For local models (LM Studio, Ollama, llama.cpp), the model can be
    # automatically restored without any API key.
    #
    # @example Creating from a model
    #   manifest = ModelManifest.from_model(my_openai_model)
    #   manifest.class_name  # => "Smolagents::OpenAIModel"
    #   manifest.model_id    # => "gemma-3n-e4b-it-q8_0"
    #
    # @example Auto-instantiating a local model
    #   model = manifest.auto_instantiate  # Works for local models
    #
    # @example Instantiating with API key
    #   model = manifest.instantiate(api_key: ENV["ANTHROPIC_API_KEY"])
    #
    # @see AgentManifest Uses ModelManifest to store model configuration
    ModelManifest = Data.define(:class_name, :model_id, :provider, :config) do
      class << self
        # Creates a manifest from an existing model instance.
        #
        # @param model [Model] The model to capture
        # @return [ModelManifest] Manifest without sensitive data
        def from_model(model)
          config = extract_safe_config(model)
          provider = detect_provider(model, config)
          new(class_name: model.class.name, model_id: model.model_id, provider:, config:)
        end

        # Creates a manifest from a hash (e.g., parsed JSON).
        #
        # @param hash [Hash] Hash representation of the manifest
        # @return [ModelManifest] Reconstructed manifest
        def from_h(hash)
          data = Serialization.symbolize_keys(hash)
          new(
            class_name: data[:class_name],
            model_id: data[:model_id],
            provider: data[:provider]&.to_sym,
            config: Serialization.symbolize_keys(data[:config] || {})
          )
        end

        private

        def extract_safe_config(model)
          Serialization.extract_ivars(model, exclude: MODEL_SENSITIVE_KEYS + MODEL_NON_SERIALIZABLE)
        end

        def detect_provider(model, config)
          return config[:provider].to_sym if config[:provider]

          api_base = config[:api_base] || config[:uri_base]
          return detect_provider_from_url(api_base) if api_base

          case model.class.name
          when "Smolagents::AnthropicModel" then :anthropic
          when "Smolagents::LiteLLMModel" then detect_litellm_provider(model)
          else :openai
          end
        end

        def detect_provider_from_url(url)
          case url
          when /localhost:1234/, /lm.studio/i then :lm_studio
          when /localhost:11434/, /ollama/i then :ollama
          when /localhost:8080/ then :llama_cpp
          when /localhost:8000/, /vllm/i then :vllm
          when /azure\.com/i then :azure
          else :openai
          end
        end

        def detect_litellm_provider(model)
          return :openai unless model.respond_to?(:provider)

          model.provider&.to_sym || :openai
        end
      end

      # Converts the manifest to a hash for JSON serialization.
      # @return [Hash] Hash representation of the manifest
      def to_h = { class_name:, model_id:, provider:, config: }

      # Checks if this model uses a local provider (no API key needed).
      # @return [Boolean] True if provider is local (LM Studio, Ollama, etc.)
      def local? = LOCAL_PROVIDERS.include?(provider)

      # Attempts to create a model instance automatically.
      #
      # For local providers (LM Studio, Ollama, llama.cpp), creates the model
      # directly. For cloud providers, checks environment variables for API keys.
      #
      # @param api_key [String, nil] Override API key
      # @param overrides [Hash] Settings to override from manifest
      # @return [Model, nil] Model instance or nil if cannot auto-create
      def auto_instantiate(api_key: nil, **overrides)
        return instantiate(api_key:, **overrides) if api_key

        if local?
          instantiate_local(**overrides)
        else
          auto_instantiate_cloud(**overrides)
        end
      rescue UntrustedClassError, NameError, ArgumentError => e
        warn "[ModelManifest#auto_instantiate] failed for #{class_name}: #{e.class} - #{e.message}" if $DEBUG
        nil
      end

      # Creates a model instance from this manifest.
      #
      # @param api_key [String, nil] API key for authentication
      # @param overrides [Hash] Settings to override from manifest
      # @return [Model] New model instance
      # @raise [UntrustedClassError] If class_name is not in allowlist
      def instantiate(api_key: nil, **overrides)
        raise UntrustedClassError.new(class_name, ALLOWED_MODEL_CLASSES.to_a) unless ALLOWED_MODEL_CLASSES.include?(class_name)

        klass = Object.const_get(class_name)
        merged_config = config.merge(overrides)
        merged_config[:api_key] = api_key if api_key && accepts_api_key?(klass)
        klass.new(model_id:, **merged_config)
      end

      private

      def instantiate_local(**overrides)
        case provider
        when :lm_studio
          OpenAIModel.lm_studio(model_id, **config, **overrides)
        when :ollama
          OpenAIModel.ollama(model_id, **config, **overrides)
        when :llama_cpp
          OpenAIModel.llama_cpp(model_id, **config, **overrides)
        when :vllm
          OpenAIModel.vllm(model_id, **config, **overrides)
        when :mlx_lm
          OpenAIModel.mlx_lm(model_id, **config, **overrides)
        else
          instantiate(api_key: "not-needed", **overrides)
        end
      end

      def auto_instantiate_cloud(**overrides)
        env_key = PROVIDER_ENV_KEYS[provider]
        api_key = env_key && ENV.fetch(env_key, nil)
        return nil unless api_key

        instantiate(api_key:, **overrides)
      end

      def accepts_api_key?(klass)
        klass.instance_method(:initialize).parameters.any? { |_, name| name == :api_key }
      end
    end
  end
end
