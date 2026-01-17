module Smolagents
  module Tools
    class Tool
      # Schema generation and prompt formatting for tools.
      #
      # Provides serialization to various formats for agent consumption.
      module Schema
        # Generates a code-style prompt for CodeAgent.
        #
        # @return [String] Ruby-style method documentation
        def to_code_prompt
          args_doc = inputs.map { |n, s| "#{n}: #{s[:description]}" }.join(", ")
          "#{name}(#{args_doc}) - #{description}"
        end

        # Generates a natural language prompt for ToolAgent.
        #
        # @return [String] Natural language tool description
        def to_tool_calling_prompt
          "#{name}: #{description}\n  Takes inputs: #{inputs}\n  Returns: #{output_type}\n"
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
        #
        # @example In agent code
        #   calculate.help  # Returns help for the calculate tool
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

        # Generate contextual tips based on output type
        def tips_for_output_type
          case output_type
          when "number", "integer"
            "TIP: Results support arithmetic! result * 2, result.round(2)"
          when "array"
            "TIP: Results are chainable! result.first, result.select { |x| x[:key] }"
          when "string"
            "TIP: Use puts(result) to see the value, then final_answer(answer: result)"
          when "object"
            "TIP: Access fields with result[:key] or result.dig(:nested, :key)"
          else
            "TIP: Use puts(result) to inspect, then final_answer(answer: result)"
          end
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
