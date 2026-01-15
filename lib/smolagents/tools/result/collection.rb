module Smolagents
  module Tools
    class ToolResult
      # Collection operations: enumerable support, chainable transformations, and aggregations.
      module Collection
        # === Enumerable Support ===

        def each(&)
          return enum_for(:each) { size } unless block_given?

          enumerable_data.each(&)
        end

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

        def map(&) = chain(:map) { @data.is_a?(Array) ? @data.map(&) : yield(@data) }
        alias collect map

        def flat_map(&) = chain(:flat_map) { @data.flat_map(&) }
        def sort_by(&) = chain(:sort_by) { @data.sort_by(&) }
        def sort(&block) = chain(:sort) { block ? @data.sort(&block) : @data.sort }
        def take(count) = chain(:take) { @data.take(count) }
        def drop(count) = chain(:drop) { @data.drop(count) }
        def take_while(&) = chain(:take_while) { @data.take_while(&) }
        def drop_while(&) = chain(:drop_while) { @data.drop_while(&) }
        def group_by(&) = chain(:group_by) { @data.group_by(&) }

        def partition(&)
          matching, non_matching = @data.partition(&)
          meta = { parent: @metadata[:created_at], op: :partition }
          [self.class.new(matching, tool_name: @tool_name, metadata: meta),
           self.class.new(non_matching, tool_name: @tool_name, metadata: meta)]
        end

        def pluck(key)
          chain(:pluck) { @data.map { |item| item.is_a?(Hash) ? (item[key] || item[key.to_s]) : item } }
        end

        # === Aggregations ===

        def min(&) = enumerable_data.min(&)
        def max(&) = enumerable_data.max(&)

        def average(&block)
          items = enumerable_data
          return 0.0 if items.empty?

          (block ? items.map(&block) : items).then { |v| v.sum.to_f / v.size }
        end

        def first(count = nil) = count ? take(count) : enumerable_data.first
        def last(count = nil) = count ? chain(:last) { @data.last(count) } : enumerable_data.last

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
