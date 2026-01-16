module Smolagents
  module Builders
    # Tool resolution helpers for AgentBuilder.
    #
    # Handles resolving tool names to instances and toolkit expansion.
    module ToolResolution
      private

      def resolve_tools
        base_tools = registry_tools_from_names + configuration[:tool_instances]
        spawn_config = configuration[:spawn_config]
        spawn_config&.enabled? ? base_tools + [build_spawn_tool(spawn_config)] : base_tools
      end

      def registry_tools_from_names
        configuration[:tool_names].map do |name|
          Tools.get(name.to_s) || raise_unknown_tool!(name)
        end
      end

      def raise_unknown_tool!(name)
        raise ArgumentError, "Unknown tool: #{name}. Available: #{Tools.names.join(", ")}"
      end

      def build_spawn_tool(spawn_config)
        inline_tools = configuration[:tool_instances].select { |t| t.is_a?(Tools::InlineTool) }
        Tools::SpawnAgentTool.new(parent_model: resolve_model, spawn_config:, inline_tools:)
      end

      def partition_tool_args(args)
        args.partition { |t| t.is_a?(Symbol) || t.is_a?(String) }
      end

      def expand_toolkits(names)
        names.flat_map { |n| Toolkits.toolkit?(n.to_sym) ? Toolkits.get(n.to_sym) : [n.to_sym] }
      end
    end
  end
end
