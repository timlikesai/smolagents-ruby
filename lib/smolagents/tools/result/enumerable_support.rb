module Smolagents
  module Tools
    class ToolResult
      # Enumerable support for ToolResult.
      #
      # Provides iteration and size methods for treating results as collections.
      module EnumerableSupport
        # Iterates over each element in the result.
        #
        # @yield [Object] Each element in the data
        # @return [Enumerator] If no block given
        # @return [self] If block given
        def each(&)
          return enum_for(:each) { size } unless block_given?

          enumerable_data.each(&)
        end

        # Returns the number of elements in the result.
        #
        # @return [Integer] Element count (0 for nil, 1 for scalar values)
        def size
          case @data
          when Array, Hash then @data.size
          when nil then 0
          else 1
          end
        end
        alias length size
        alias count size
      end
    end
  end
end
