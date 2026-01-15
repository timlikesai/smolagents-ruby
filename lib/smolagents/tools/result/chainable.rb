module Smolagents
  module Tools
    class ToolResult
      # Chainable transformation methods for ToolResult.
      # All methods return new ToolResult instances, enabling fluent method chaining.
      module Chainable
        # Define chainable methods that delegate to the underlying data.
        def self.included(base)
          %i[select reject compact uniq reverse flatten].each do |method|
            base.define_method(method) do |*args, &block|
              chain(method) { block ? @data.public_send(method, *args, &block) : @data.public_send(method, *args) }
            end
          end
          base.alias_method :filter, :select
        end

        # @return [ToolResult] New result with transformed data
        def map(&) = chain(:map) { @data.is_a?(Array) ? @data.map(&) : yield(@data) }
        alias collect map

        # @return [ToolResult] New result with flattened mapped data
        def flat_map(&) = chain(:flat_map) { @data.flat_map(&) }

        # @return [ToolResult] New result sorted by block return value
        def sort_by(&) = chain(:sort_by) { @data.sort_by(&) }

        # @return [ToolResult] New result with sorted data
        def sort(&block) = chain(:sort) { block ? @data.sort(&block) : @data.sort }

        # @return [ToolResult] New result with first n elements
        def take(count) = chain(:take) { @data.take(count) }

        # @return [ToolResult] New result without first n elements
        def drop(count) = chain(:drop) { @data.drop(count) }

        # @return [ToolResult] Elements taken while block returns true
        def take_while(&) = chain(:take_while) { @data.take_while(&) }

        # @return [ToolResult] Elements after dropping while block returns true
        def drop_while(&) = chain(:drop_while) { @data.drop_while(&) }

        # @return [ToolResult] New result with Hash of grouped data
        def group_by(&) = chain(:group_by) { @data.group_by(&) }

        # @return [Array<ToolResult, ToolResult>] Two results: matching and non-matching
        def partition(&)
          matching, non_matching = @data.partition(&)
          meta = { parent: @metadata[:created_at], op: :partition }
          [self.class.new(matching, tool_name: @tool_name, metadata: meta),
           self.class.new(non_matching, tool_name: @tool_name, metadata: meta)]
        end

        # Extracts a specific key from each Hash element.
        # @return [ToolResult] New result with extracted values
        def pluck(key)
          chain(:pluck) { @data.map { |item| item.is_a?(Hash) ? (item[key] || item[key.to_s]) : item } }
        end
      end
    end
  end
end
