module Smolagents
  module Persistence
    MODEL_SENSITIVE_KEYS = %i[api_key access_token auth_token bearer_token password secret
                              credential api_secret private_key].freeze
    MODEL_NON_SERIALIZABLE = %i[client logger model_id kwargs].freeze

    ALLOWED_MODEL_CLASSES = Set.new(%w[
                                      Smolagents::OpenAIModel
                                      Smolagents::AnthropicModel
                                      Smolagents::LiteLLMModel
                                    ]).freeze

    ModelManifest = Data.define(:class_name, :model_id, :config) do
      class << self
        def from_model(model)
          config = extract_safe_config(model)
          new(class_name: model.class.name, model_id: model.model_id, config:)
        end

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

      def to_h = { class_name:, model_id:, config: }

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
