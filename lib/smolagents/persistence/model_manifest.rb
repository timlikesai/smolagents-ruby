require_relative "model_manifest_support"

module Smolagents
  module Persistence
    # Immutable manifest describing a model's configuration.
    #
    # Captures information needed to reconstruct a model, excluding API keys
    # and sensitive data. Local models (LM Studio, Ollama) restore automatically.
    #
    # @example manifest = ModelManifest.from_model(model)
    # @example model = manifest.auto_instantiate  # Local models
    # @example model = manifest.instantiate(api_key: key)  # Cloud models
    ModelManifest = Data.define(:class_name, :model_id, :provider, :config) do
      class << self
        # Creates a manifest from an existing model instance.
        def from_model(model)
          config = extract_safe_config(model)
          provider = ModelManifestSupport.detect_provider(model, config)
          new(class_name: model.class.name, model_id: model.model_id, provider:, config:)
        end

        # Creates a manifest from a hash (e.g., parsed JSON).
        def from_h(hash)
          data = Serialization.symbolize_keys(hash)
          new(class_name: data[:class_name], model_id: data[:model_id],
              provider: data[:provider]&.to_sym,
              config: Serialization.symbolize_keys(data[:config] || {}))
        end

        private

        def extract_safe_config(model)
          exclude = ModelManifestSupport::SENSITIVE_KEYS + ModelManifestSupport::NON_SERIALIZABLE_KEYS
          Serialization.extract_ivars(model, exclude:)
        end
      end

      # Converts the manifest to a hash for JSON serialization.
      def to_h = { class_name:, model_id:, provider:, config: }

      # Checks if this model uses a local provider (no API key needed).
      def local? = ModelManifestSupport::LOCAL_PROVIDERS.include?(provider)

      # Attempts to create a model instance automatically.
      # For local providers, creates directly. For cloud, checks environment variables.
      def auto_instantiate(api_key: nil, **overrides)
        return instantiate(api_key:, **overrides) if api_key

        local? ? instantiate_local(**overrides) : auto_instantiate_cloud(**overrides)
      rescue UntrustedClassError, NameError, ArgumentError => e
        warn "[ModelManifest] auto_instantiate failed for #{class_name}: #{e.class}" if $DEBUG
        nil
      end

      # Creates a model instance from this manifest.
      # @raise [UntrustedClassError] If class_name is not in allowlist
      def instantiate(api_key: nil, **overrides)
        validate_class!
        klass = Object.const_get(class_name)
        merged = config.merge(overrides)
        merged[:api_key] = api_key if api_key && accepts_api_key?(klass)
        klass.new(model_id:, **merged)
      end

      private

      def validate_class!
        return if ModelManifestSupport::ALLOWED_CLASSES.include?(class_name)

        raise UntrustedClassError.new(class_name, ModelManifestSupport::ALLOWED_CLASSES.to_a)
      end

      def instantiate_local(**overrides)
        method = ModelManifestSupport::PROVIDER_METHODS[provider]
        return OpenAIModel.public_send(method, model_id, **config, **overrides) if method

        instantiate(api_key: "not-needed", **overrides)
      end

      def auto_instantiate_cloud(**overrides)
        env_key = ModelManifestSupport::ENV_KEYS[provider]
        api_key = env_key && ENV.fetch(env_key, nil)
        api_key ? instantiate(api_key:, **overrides) : nil
      end

      def accepts_api_key?(klass)
        klass.instance_method(:initialize).parameters.any? { |_, name| name == :api_key }
      end
    end
  end
end
