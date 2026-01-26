module Smolagents
  module Tools
    class Tool
      # Schema generation and prompt formatting for tools.
      #
      # Provides serialization to various formats for agent consumption.
      # Uses {ToolFormatter} for format-agnostic tool rendering.
      #
      # @see ToolFormatter For the formatting abstraction
      # @see Tools::Formattable For the format_for interface
      module Schema
        # Format this tool for the given context.
        #
        # Decouples tool formatting from agent type assumptions.
        # Delegates to registered formatters in {ToolFormatter}.
        #
        # @param format [Symbol] Format type (:code, :tool_calling, etc.)
        # @return [String] Formatted tool description
        #
        # @example
        #   tool.format_for(:code)          # => "search(query: ...) - ..."
        #   tool.format_for(:tool_calling)  # => "search: ...\n  Takes inputs: ..."
        def format_for(format)
          ToolFormatter.format(self, format:)
        end

        # Converts the tool's metadata to a hash.
        #
        # @return [Hash{Symbol => Object}] Tool metadata
        def to_h = { name:, description:, inputs:, output_type:, output_schema: }.compact

        # Returns concise help text for this tool.
        #
        # Provides a brief description, argument list, and usage example.
        # Callable from agent code to get help on how to use a tool.
        #
        # @return [String] Help text
        def help
          args_str = inputs.map { |n, s| "#{n}: #{format_type(s)}" }.join(", ")
          example_args = inputs.map { |n, s| "#{n}: #{example_value(s)}" }.join(", ")

          <<~HELP.strip
            #{name}(#{args_str}) -> #{output_type}
            #{description}

            Example: result = #{name}(#{example_args})

            #{tips_for_output_type}
          HELP
        end

        OUTPUT_TYPE_TIPS = {
          "number" => "TIP: Results support arithmetic! result * 2, result.round(2)",
          "integer" => "TIP: Results support arithmetic! result * 2, result.round(2)",
          "array" => "TIP: Results are chainable! result.first, result.select { |x| x[:key] }",
          "string" => "TIP: Use puts(result) to see the value, then final_answer(answer: result)",
          "object" => "TIP: Access fields with result[:key] or result.dig(:nested, :key)"
        }.freeze

        def tips_for_output_type
          OUTPUT_TYPE_TIPS.fetch(output_type, "TIP: Use puts(result) to inspect, then final_answer(answer: result)")
        end

        private

        def format_type(schema)
          type = schema[:type] || schema["type"]
          nullable = schema[:nullable] || schema["nullable"]
          nullable ? "#{type}?" : type
        end

        def example_value(schema)
          type = schema[:type] || schema["type"]
          case type
          when "string" then '"example"'
          when "number", "integer" then "42"
          when "boolean" then "true"
          when "array" then "[...]"
          when "object" then "{...}"
          else "value"
          end
        end
      end
    end
  end
end
