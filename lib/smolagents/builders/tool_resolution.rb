module Smolagents
  module Builders
    # Tool resolution helpers for AgentBuilder.
    #
    # Handles resolving tool names to instances and toolkit expansion.
    module ToolResolution
      private

      # Resolve tools from names and instances, adding spawn tool if enabled.
      # @return [Array] Resolved tool instances
      def resolve_tools
        base_tools = registry_tools_from_names + configuration[:tool_instances]
        spawn_config = configuration[:spawn_config]
        spawn_config&.enabled? ? base_tools + [build_spawn_tool(spawn_config)] : base_tools
      end

      # Convert tool names to tool instances from registry.
      # @return [Array] Tool instances
      def registry_tools_from_names
        configuration[:tool_names].map do |name|
          Tools.get(name.to_s) || raise_unknown_tool!(name)
        end
      end

      # Raise an error for unknown tool name.
      # @param name [Symbol] Tool name
      # @return [void]
      # @raise [ArgumentError]
      def raise_unknown_tool!(name)
        raise ArgumentError, "Unknown tool: #{name}. Available: #{Tools.names.join(", ")}"
      end

      # Build a SpawnAgentTool with proper configuration.
      # @param spawn_config [Types::SpawnConfig] Spawn configuration
      # @return [Tools::SpawnAgentTool]
      def build_spawn_tool(spawn_config)
        inline_tools = configuration[:tool_instances].select { |t| t.is_a?(Tools::InlineTool) }
        Tools::SpawnAgentTool.new(parent_model: resolve_model, spawn_config:, inline_tools:)
      end

      # Partition tool args into names and instances.
      # @param args [Array] Tool arguments
      # @return [Array] [names, instances] tuple
      def partition_tool_args(args)
        args.partition { |t| t.is_a?(Symbol) || t.is_a?(String) }
      end

      # Expand toolkit names to their tool lists.
      # @param names [Array<Symbol>] Toolkit or tool names
      # @return [Array<Symbol>] Expanded tool names
      def expand_toolkits(names)
        names.flat_map { |n| Toolkits.toolkit?(n.to_sym) ? Toolkits.get(n.to_sym) : [n.to_sym] }
      end
    end
  end
end
