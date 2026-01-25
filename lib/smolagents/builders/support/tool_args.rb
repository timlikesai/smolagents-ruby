module Smolagents
  module Builders
    module Support
      # Reusable helpers for tool argument processing.
      #
      # Provides partitioning of tool arguments into names vs instances,
      # and expansion of toolkit names to their constituent tools.
      #
      # @example Partitioning tool arguments
      #   names, instances = partition_tool_args([:search, :web, tool_instance])
      #   names      #=> [:search, :web]
      #   instances  #=> [tool_instance]
      #
      # @example Expanding toolkits
      #   expand_toolkits([:search])
      #   #=> [:duckduckgo_search, :wikipedia_search, ...]
      module ToolArgs
        private

        # Partition tool arguments into symbols/strings and instances.
        # @param args [Array] Tool arguments
        # @return [Array] [names, instances] tuple
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
end
