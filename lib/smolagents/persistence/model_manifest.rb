module Smolagents
  module Persistence
    module ModelManifestConstants
      SENSITIVE_KEYS = %i[api_key access_token auth_token bearer_token password secret
                          credential api_secret private_key].freeze
      NON_SERIALIZABLE = %i[client logger].freeze
    end

    ModelManifest = Data.define(:class_name, :model_id, :config) do
      include ModelManifestConstants

      class << self
        include ModelManifestConstants

        def from_model(model)
          config = extract_safe_config(model)
          new(class_name: model.class.name, model_id: model.model_id, config:)
        end

        def from_h(hash)
          h = hash.transform_keys(&:to_sym)
          new(
            class_name: h[:class_name],
            model_id: h[:model_id],
            config: (h[:config] || {}).transform_keys(&:to_sym)
          )
        end

        private

        def extract_safe_config(model)
          model.instance_variables
               .reject { |v| sensitive_key?(v) || non_serializable?(v) }
               .to_h { |v| [v.to_s.delete_prefix("@").to_sym, model.instance_variable_get(v)] }
               .except(:model_id, :kwargs)
               .select { |_, v| serializable_value?(v) }
        end

        def sensitive_key?(var)
          key = var.to_s.delete_prefix("@").to_sym
          SENSITIVE_KEYS.include?(key)
        end

        def non_serializable?(var)
          NON_SERIALIZABLE.include?(var.to_s.delete_prefix("@").to_sym)
        end

        def serializable_value?(value)
          case value
          when nil, true, false, Numeric, String, Symbol then true
          when Array then value.all? { |v| serializable_value?(v) }
          when Hash then value.all? { |k, v| serializable_value?(k) && serializable_value?(v) }
          else false
          end
        end
      end

      def to_h = { class_name:, model_id:, config: }

      def instantiate(api_key: nil, **overrides)
        klass = Object.const_get(class_name)
        merged_config = config.merge(overrides)
        merged_config[:api_key] = api_key if api_key && klass.instance_method(:initialize).parameters.any? { |_, n| n == :api_key }
        klass.new(model_id:, **merged_config)
      end
    end
  end
end
