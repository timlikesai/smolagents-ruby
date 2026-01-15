module Smolagents
  module Tools
    class ToolResult
      # Aggregation and element access methods for ToolResult.
      #
      # Provides min, max, average, and element access (first, last, dig).
      module Aggregations
        # Returns the minimum element.
        #
        # @yield [Object, Object] Optional comparison block
        # @return [Object] The minimum element
        def min(&) = enumerable_data.min(&)

        # Returns the maximum element.
        #
        # @yield [Object, Object] Optional comparison block
        # @return [Object] The maximum element
        def max(&) = enumerable_data.max(&)

        # Calculates the average of numeric values.
        #
        # @yield [Object] Optional block to extract numeric value from each element
        # @return [Float] The average value (0.0 if empty)
        def average(&block)
          items = enumerable_data
          return 0.0 if items.empty?

          (block ? items.map(&block) : items).then { |values| values.sum.to_f / values.size }
        end

        # Returns the first element(s).
        #
        # @overload first
        #   @return [Object] The first element
        # @overload first(count)
        #   @param count [Integer] Number of elements
        #   @return [ToolResult] New result with first n elements
        def first(count = nil) = count ? take(count) : enumerable_data.first

        # Returns the last element(s).
        #
        # @overload last
        #   @return [Object] The last element
        # @overload last(count)
        #   @param count [Integer] Number of elements
        #   @return [ToolResult] New result with last n elements
        def last(count = nil) = count ? chain(:last) { @data.last(count) } : enumerable_data.last

        # Navigates nested data structures.
        #
        # @param keys [Array<String, Symbol, Integer>] Keys/indices to navigate
        # @return [Object, nil] The value at the path, or nil if not found
        def dig(*keys)
          @data.dig(*keys)
        rescue TypeError, NoMethodError => e
          warn "[ToolResult#dig] failed to navigate path #{keys.inspect}: #{e.class} - #{e.message}" if $DEBUG
          nil
        end
      end
    end
  end
end
