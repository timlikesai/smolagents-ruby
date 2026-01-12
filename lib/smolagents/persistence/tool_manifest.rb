module Smolagents
  module Persistence
    TOOL_EXCLUDED_IVARS = %i[initialized].freeze

    ToolManifest = Data.define(:name, :class_name, :registry_key, :config) do
      class << self
        def from_tool(tool)
          registry_key = find_registry_key(tool)
          raise UnserializableToolError.new(tool.name, tool.class.name) unless registry_key

          new(
            name: tool.name,
            class_name: tool.class.name,
            registry_key:,
            config: Serialization.extract_ivars(tool, exclude: TOOL_EXCLUDED_IVARS)
          )
        end

        def from_h(hash)
          h = Serialization.symbolize_keys(hash)
          new(
            name: h[:name],
            class_name: h[:class_name],
            registry_key: h[:registry_key],
            config: Serialization.symbolize_keys(h[:config] || {})
          )
        end

        private

        def find_registry_key(tool)
          Tools::REGISTRY.find { |_, klass| tool.instance_of?(klass) }&.first
        end
      end

      def to_h = { name:, class_name:, registry_key:, config: }

      def registry_tool? = Tools::REGISTRY.key?(registry_key)

      def instantiate(**overrides)
        klass = Tools::REGISTRY[registry_key]
        raise UnknownToolError, registry_key unless klass

        merged = config.merge(overrides)
        merged.empty? ? klass.new : klass.new(**merged)
      rescue ArgumentError
        klass.new
      end
    end
  end
end
