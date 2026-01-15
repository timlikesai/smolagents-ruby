module Smolagents
  module Tools
    class ToolResult
      # Pattern matching support for ToolResult.
      #
      # Enables Ruby 3.0+ pattern matching with both array and hash deconstruction.
      #
      # @example Array deconstruction
      #   case result
      #   in [first, *rest] then process(first, rest)
      #   end
      #
      # @example Hash deconstruction
      #   case result
      #   in ToolResult[data: Array, error?: false]
      #     puts "Success with array data"
      #   end
      module PatternMatching
        # Enables array-style pattern matching.
        #
        # @return [Array] Array representation for pattern matching
        def deconstruct = to_a

        # Enables hash-style pattern matching.
        #
        # @param keys [Array<Symbol>, nil] Keys to extract (nil for all)
        # @return [Hash] Hash with requested keys for pattern matching
        def deconstruct_keys(keys)
          {
            data: @data,
            tool_name: @tool_name,
            metadata: @metadata,
            empty?: empty?,
            error?: error?
          }.then { |hash| keys ? hash.slice(*keys) : hash }
        end
      end
    end
  end
end
