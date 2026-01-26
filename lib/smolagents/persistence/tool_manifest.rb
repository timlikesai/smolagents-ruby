module Smolagents
  module Persistence
    # @return [Array<Symbol>] Instance variables excluded from tool serialization
    TOOL_EXCLUDED_IVARS = %i[initialized].freeze

    # Immutable manifest describing a tool's configuration.
    #
    # ToolManifest captures the information needed to reconstruct a tool
    # from the registry. Only registry tools can be serialized for security.
    #
    # @example Creating from a tool
    #   manifest = ToolManifest.from_tool(FinalAnswerTool.new)
    #   manifest.name         # => "final_answer"
    #   manifest.registry_key # => "final_answer"
    #
    # @example Instantiating a tool
    #   tool = manifest.instantiate
    #
    # @see AgentManifest Uses ToolManifest to store tool configurations
    # @see Tools::REGISTRY Source of allowed tools
    ToolManifest = Data.define(:name, :class_name, :registry_key, :config) do
      class << self
        # Creates a manifest from an existing tool instance.
        #
        # @param tool [Tool] The tool to capture
        # @return [ToolManifest] Manifest with registry key and config
        # @raise [UnserializableToolError] If tool is not in registry
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

        # Creates a manifest from a hash (e.g., parsed JSON).
        #
        # @param hash [Hash] Hash representation of the manifest
        # @return [ToolManifest] Reconstructed manifest
        def from_h(hash)
          data = Serialization.symbolize_keys(hash)
          new(
            name: data[:name],
            class_name: data[:class_name],
            registry_key: data[:registry_key],
            config: Serialization.symbolize_keys(data[:config] || {})
          )
        end

        private

        def find_registry_key(tool)
          Tools::REGISTRY.find { |_, klass| tool.instance_of?(klass) }&.first
        end
      end

      # Converts the manifest to a hash for JSON serialization.
      # @return [Hash] Hash representation of the manifest
      def to_h = { name:, class_name:, registry_key:, config: }

      # Checks if this tool's registry key is still valid.
      # @return [Boolean] True if tool exists in registry
      def registry_tool? = Tools::REGISTRY.key?(registry_key)

      # Creates a tool instance from this manifest.
      #
      # @param overrides [Hash] Settings to override from manifest
      # @return [Tool] New tool instance from registry
      # @raise [UnknownToolError] If registry_key not in registry
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
