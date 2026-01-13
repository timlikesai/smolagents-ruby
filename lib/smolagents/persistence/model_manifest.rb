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

    # Immutable manifest describing a model's configuration.
    #
    # ModelManifest captures the information needed to reconstruct a model,
    # except for API keys and other sensitive data which are never serialized.
    #
    # @example Creating from a model
    #   manifest = ModelManifest.from_model(my_openai_model)
    #   manifest.class_name  # => "Smolagents::OpenAIModel"
    #   manifest.model_id    # => "gpt-4"
    #
    # @example Instantiating a model (API key required)
    #   model = manifest.instantiate(api_key: ENV["OPENAI_API_KEY"])
    #
    # @see AgentManifest Uses ModelManifest to store model configuration
    ModelManifest = Data.define(:class_name, :model_id, :config) do
      class << self
        # Creates a manifest from an existing model instance.
        #
        # @param model [Model] The model to capture
        # @return [ModelManifest] Manifest without sensitive data
        def from_model(model)
          config = extract_safe_config(model)
          new(class_name: model.class.name, model_id: model.model_id, config:)
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
            config: Serialization.symbolize_keys(data[:config] || {})
          )
        end

        private

        def extract_safe_config(model)
          Serialization.extract_ivars(model, exclude: MODEL_SENSITIVE_KEYS + MODEL_NON_SERIALIZABLE)
        end
      end

      # Converts the manifest to a hash for JSON serialization.
      # @return [Hash] Hash representation of the manifest
      def to_h = { class_name:, model_id:, config: }

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

      def accepts_api_key?(klass)
        klass.instance_method(:initialize).parameters.any? { |_, name| name == :api_key }
      end
    end
  end
end
