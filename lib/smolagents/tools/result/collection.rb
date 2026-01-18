module Smolagents
  module Tools
    class ToolResult
      # Collection operations: enumerable support, chainable transformations, and aggregations.
      module Collection
        # === Enumerable Support ===

        # Iterates over result elements, supporting Enumerable pattern.
        #
        # @yield [item] Block to execute for each element
        # @return [Enumerator, self] Enumerator if no block given, otherwise self
        def each(&)
          return enum_for(:each) { size } unless block_given?

          enumerable_data.each(&)
        end

        # Returns the number of elements in the result.
        #
        # @return [Integer] Number of items (1 for scalars, size for arrays/hashes, 0 for nil)
        def size
          case @data
          when Array, Hash then @data.size
          when nil then 0
          else 1
          end
        end
        alias length size
        alias count size

        # === Chainable Transformations ===

        def self.included(base)
          %i[select reject compact uniq reverse flatten].each do |method|
            base.define_method(method) do |*args, &block|
              chain(method) { block ? @data.public_send(method, *args, &block) : @data.public_send(method, *args) }
            end
          end
          base.alias_method :filter, :select
        end

        # Maps each element through a block, returning a new ToolResult.
        #
        # @yield [item] Block to transform each element
        # @return [ToolResult] New result with mapped data
        def map(&) = chain(:map) { @data.is_a?(Array) ? @data.map(&) : yield(@data) }
        alias collect map

        # Maps and flattens elements in one operation.
        #
        # @yield [item] Block returning enumerables to flatten
        # @return [ToolResult] New result with flat-mapped data
        def flat_map(&) = chain(:flat_map) { @data.flat_map(&) }

        # Sorts elements by the result of a block.
        #
        # @yield [item] Block returning comparison key
        # @return [ToolResult] New result with sorted data
        def sort_by(&) = chain(:sort_by) { @data.sort_by(&) }

        # Sorts elements in natural order or by given block.
        #
        # @yield [a, b] Optional comparison block
        # @return [ToolResult] New result with sorted data
        def sort(&block) = chain(:sort) { block ? @data.sort(&block) : @data.sort }

        # Returns first N elements.
        #
        # @param count [Integer] Number of elements to take
        # @return [ToolResult] New result with first N elements
        def take(count) = chain(:take) { @data.take(count) }

        # Returns all elements except the first N.
        #
        # @param count [Integer] Number of elements to skip
        # @return [ToolResult] New result with remaining elements
        def drop(count) = chain(:drop) { @data.drop(count) }

        # Takes elements while block returns true.
        #
        # @yield [item] Condition to continue taking
        # @return [ToolResult] New result with taken elements
        def take_while(&) = chain(:take_while) { @data.take_while(&) }

        # Drops elements while block returns true.
        #
        # @yield [item] Condition to continue dropping
        # @return [ToolResult] New result with remaining elements
        def drop_while(&) = chain(:drop_while) { @data.drop_while(&) }

        # Groups elements by the result of a block.
        #
        # @yield [item] Block returning grouping key
        # @return [ToolResult] New result with grouped data (Hash of groups)
        def group_by(&) = chain(:group_by) { @data.group_by(&) }

        # Splits elements into two ToolResults based on block condition.
        #
        # @yield [item] Condition to partition by
        # @return [Array<ToolResult>] Two results: matching and non-matching elements
        def partition(&)
          matching, non_matching = @data.partition(&)
          meta = { parent: @metadata[:created_at], op: :partition }
          [self.class.new(matching, tool_name: @tool_name, metadata: meta),
           self.class.new(non_matching, tool_name: @tool_name, metadata: meta)]
        end

        # Extracts specified key from hash elements.
        #
        # @param key [String, Symbol] Key to pluck from each hash element
        # @return [ToolResult] New result with plucked values
        def pluck(key)
          chain(:pluck) { @data.map { |item| item.is_a?(Hash) ? (item[key] || item[key.to_s]) : item } }
        end

        # === Aggregations ===

        # Returns minimum element using optional block comparison.
        #
        # @yield [a, b] Optional comparison block
        # @return [Object] Minimum element
        def min(&) = enumerable_data.min(&)

        # Returns maximum element using optional block comparison.
        #
        # @yield [a, b] Optional comparison block
        # @return [Object] Maximum element
        def max(&) = enumerable_data.max(&)

        # Calculates average of numeric elements.
        #
        # @yield [item] Optional block to extract numeric values
        # @return [Float] Average value (0.0 for empty)
        def average(&block)
          items = enumerable_data
          return 0.0 if items.empty?

          (block ? items.map(&block) : items).then { |v| v.sum.to_f / v.size }
        end

        # Returns first element or first N elements.
        #
        # @param count [Integer, nil] Number of elements to return
        # @return [Object, ToolResult] Single element or new result with first N elements
        def first(count = nil) = count ? take(count) : enumerable_data.first

        # Returns last element or last N elements.
        #
        # @param count [Integer, nil] Number of elements to return
        # @return [Object, ToolResult] Single element or new result with last N elements
        def last(count = nil) = count ? chain(:last) { @data.last(count) } : enumerable_data.last

        # Navigates nested data structures using dot notation.
        #
        # @param keys [*Object] Keys to navigate through data structure
        # @return [Object, nil] Value at the path or nil if not found
        def dig(*keys)
          @data.dig(*keys)
        rescue TypeError, NoMethodError => e
          warn "[ToolResult#dig] failed: #{keys.inspect}: #{e.class}" if $DEBUG
          nil
        end
      end
    end
  end
end
