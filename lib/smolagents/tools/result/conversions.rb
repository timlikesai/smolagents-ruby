module Smolagents
  module Tools
    class ToolResult
      # Conversion methods for ToolResult.
      #
      # Provides to_a, to_h, to_s, as_json, and inspect for various output formats.
      module Conversions
        # Converts the result to an Array.
        #
        # @return [Array] Array representation of the data
        def to_a
          case @data
          when Array then @data.dup
          when Hash then @data.to_a
          when nil then []
          else [@data]
          end
        end
        alias to_ary to_a

        # Converts the result to a Hash with full metadata.
        #
        # @return [Hash] Hash with :data, :tool_name, and :metadata keys
        def to_h = { data: @data, tool_name: @tool_name, metadata: @metadata }
        alias to_hash to_h

        # Returns a string representation (Markdown format).
        #
        # @return [String] Markdown-formatted string
        # @see #as_markdown
        def to_s = as_markdown
        alias to_str to_s

        # Returns the data for JSON serialization.
        #
        # @return [Object] The raw data suitable for JSON encoding
        def as_json(*) = @data

        # Returns a developer-friendly string representation.
        #
        # @return [String] Inspect string showing class, tool name, and data preview
        def inspect
          preview = case @data
                    when Array then "[#{@data.size} items]"
                    when Hash then "{#{@data.size} keys}"
                    when String then @data.length > 40 ? "\"#{@data[0..37]}...\"" : @data.inspect
                    else @data.inspect.then { |str| str.length > 40 ? "#{str[0..37]}..." : str }
                    end
          "#<#{self.class} tool=#{@tool_name} data=#{preview}>"
        end
      end
    end
  end
end
