module Smolagents
  module Builders
    # Tool configuration DSL methods for AgentBuilder.
    #
    # Handles adding tools by name, toolkit, or instance.
    module AgentToolsConcern
      # Add tools by name, toolkit, or instance.
      #
      # Toolkit names (`:search`, `:web`, `:data`, `:research`) are automatically
      # expanded to their tool lists. Tool instances can be passed directly.
      #
      # @param names_or_instances [Array<Symbol, String, Tool>] Tools, toolkits, or instances
      # @return [AgentBuilder] New builder with tools added
      #
      # @example Adding a single toolkit (symbol)
      #   builder = Smolagents.agent.tools(:search)
      #   builder.config[:tool_names].include?(:duckduckgo_search)  #=> true
      #
      # @example Combining multiple toolkits
      #   builder = Smolagents.agent.tools(:search, :web)
      #   builder.config[:tool_names].include?(:visit_webpage)  #=> true
      #
      # @example Adding individual tools (symbol)
      #   builder = Smolagents.agent.tools(:duckduckgo_search, :wikipedia_search)
      #   builder.config[:tool_names].size  #=> 2
      #
      # @example Adding tool instances (object)
      #   tool = Smolagents::Tools::FinalAnswerTool.new
      #   builder = Smolagents.agent.tools(tool)
      #   builder.config[:tool_instances].size  #=> 1
      def tools(*names_or_instances)
        check_frozen!
        names, instances = partition_tool_args(names_or_instances.flatten)
        with_config(tool_names: configuration[:tool_names] + expand_toolkits(names),
                    tool_instances: configuration[:tool_instances] + instances)
      end

      private

      # Partition tool arguments into symbols and instances.
      # @param args [Array] Tool arguments
      # @return [Array] [symbols, instances] tuple
      def partition_tool_args(args)
        args.partition { |t| t.is_a?(Symbol) || t.is_a?(String) }
      end

      # Expand toolkit names to individual tool lists.
      # @param names [Array<Symbol>] Toolkit or tool names
      # @return [Array<Symbol>] Expanded tool names
      def expand_toolkits(names)
        names.flat_map { |n| Toolkits.toolkit?(n.to_sym) ? Toolkits.get(n.to_sym) : [n.to_sym] }
      end
    end
  end
end
