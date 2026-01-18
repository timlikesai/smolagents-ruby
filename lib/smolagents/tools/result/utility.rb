module Smolagents
  module Tools
    class ToolResult
      # Utility methods: status predicates, conversions, pattern matching, and comparison.
      module Utility
        # === Status Predicates ===

        def empty? = @data.nil? || (@data.respond_to?(:empty?) && @data.empty?)
        def error? = @metadata[:success] == false || @metadata.key?(:error)
        def success? = !error?

        def include?(value)
          deep_include?(@data, value) || (error? && @metadata[:error].to_s.include?(value.to_s))
        end

        private

        def deep_include?(data, value)
          case data
          when String then data.include?(value.to_s)
          when Array then data.any? { |item| deep_include?(item, value) }
          when Hash then data.values.any? { |v| deep_include?(v, value) }
          else data.to_s.include?(value.to_s)
          end
        end

        public

        alias member? include?

        # === Conversions ===

        def to_a
          case @data
          when Array then @data.dup
          when Hash then @data.to_a
          when nil then []
          else [@data]
          end
        end
        alias to_ary to_a

        def to_h = { data: @data, tool_name: @tool_name, metadata: @metadata }
        alias to_hash to_h

        def to_s = as_markdown
        alias to_str to_s

        def as_json(*) = @data

        def inspect
          preview = case @data
                    when Array then "[#{@data.size} items]"
                    when Hash then "{#{@data.size} keys}"
                    when String then @data.length > 40 ? "\"#{@data[0..37]}...\"" : @data.inspect
                    else @data.inspect.then { |s| s.length > 40 ? "#{s[0..37]}..." : s }
                    end
          "#<#{self.class} tool=#{@tool_name} data=#{preview}>"
        end

        # === Pattern Matching ===

        def deconstruct = to_a

        def deconstruct_keys(keys)
          hash = { data: @data, tool_name: @tool_name, metadata: @metadata, empty?: empty?, error?: error? }
          keys ? hash.slice(*keys) : hash
        end

        # === Comparison ===

        def ==(other)
          other.is_a?(ToolResult) ? @data == other.data && @tool_name == other.tool_name : @data == other
        end
        alias eql? ==

        def hash = [@data, @tool_name].hash
      end
    end
  end
end
