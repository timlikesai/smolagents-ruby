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

        # Generates a natural language prompt for ToolCallingAgent.
        #
        # @return [String] Natural language tool description
        def to_tool_calling_prompt
          "#{name}: #{description}\n  Takes inputs: #{inputs}\n  Returns: #{output_type}\n"
        end

        # Converts the tool's metadata to a hash.
        #
        # @return [Hash{Symbol => Object}] Tool metadata
        def to_h = { name:, description:, inputs:, output_type:, output_schema: }.compact
      end
    end
  end
end
