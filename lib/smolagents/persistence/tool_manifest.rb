module Smolagents
  module Persistence
    ToolManifest = Data.define(:name, :class_name, :registry_key, :config) do
      class << self
        def from_tool(tool)
          registry_key = find_registry_key(tool)
          raise UnserializableToolError.new(tool.name, tool.class.name) unless registry_key

          new(
            name: tool.name,
            class_name: tool.class.name,
            registry_key:,
            config: extract_config(tool)
          )
        end

        def from_h(hash)
          h = hash.transform_keys(&:to_sym)
          new(
            name: h[:name],
            class_name: h[:class_name],
            registry_key: h[:registry_key],
            config: (h[:config] || {}).transform_keys(&:to_sym)
          )
        end

        private

        def find_registry_key(tool)
          Tools::REGISTRY.find { |_, klass| tool.instance_of?(klass) }&.first
        end

        def extract_config(tool)
          return {} unless tool.respond_to?(:instance_variables)

          tool.instance_variables
              .reject { |v| %i[@initialized].include?(v) }
              .to_h { |v| [v.to_s.delete_prefix("@").to_sym, tool.instance_variable_get(v)] }
              .select { |_, v| serializable_value?(v) }
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

      def to_h = { name:, class_name:, registry_key:, config: }

      def registry_tool? = Tools::REGISTRY.key?(registry_key)

      def instantiate(**overrides)
        klass = Tools::REGISTRY[registry_key]
        raise UnknownToolError, registry_key unless klass

        merged_config = config.merge(overrides)
        merged_config.empty? ? klass.new : klass.new(**merged_config)
      rescue ArgumentError
        klass.new
      end
    end
  end
end
