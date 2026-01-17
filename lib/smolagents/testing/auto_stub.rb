module Smolagents
  module Testing
    # Auto-generate MockModel responses based on tool schemas.
    #
    # Creates plausible mock behavior without manual configuration,
    # enabling fast unit tests that verify agent logic.
    #
    # @example Zero-config mock
    #   mock = AutoStub.mock_for_tools(:calculator, :web_search)
    #   agent = Smolagents.agent.tools(:calculator, :web_search).model { mock }.build
    #   result = agent.run("Calculate something")  # Just works!
    module AutoStub
      extend self

      # Create a MockModel that auto-responds based on tool schemas.
      #
      # @param tool_names [Array<Symbol>] Names of tools to stub
      # @param final_answer [String] Answer to return at the end
      # @return [MockModel] Configured mock
      def mock_for_tools(*tool_names, final_answer: "Task completed")
        mock = MockModel.new
        tool_names.flatten.each { |name| queue_tool_call(mock, name) }
        mock.queue_final_answer(final_answer)
        mock
      end

      def queue_tool_call(mock, tool_name)
        tool = resolve_tool(tool_name)
        mock.queue_code_action(tool ? generate_tool_call(tool) : "#{tool_name}()")
      end

      # Generate a plausible tool call string from tool schema.
      #
      # @param tool [Tool] The tool to generate a call for
      # @return [String] Ruby code calling the tool
      def generate_tool_call(tool)
        args = generate_arguments(tool)
        if args.empty?
          "#{tool.name}()"
        else
          "#{tool.name}(#{args.join(", ")})"
        end
      end

      # Generate plausible argument values from input schema.
      #
      # @param tool [Tool] The tool
      # @return [Array<String>] Argument strings like "query: \"test\""
      def generate_arguments(tool)
        return [] unless tool.respond_to?(:inputs) && tool.inputs.is_a?(Hash)

        tool.inputs.filter_map do |name, spec|
          next unless spec.is_a?(Hash)

          value = generate_value_for_type(spec[:type], name)
          "#{name}: #{value}"
        end
      end

      # Generate a plausible value for a given type.
      #
      # @param type [String] The input type
      # @param name [String] The input name (for contextual values)
      # @return [String] Ruby literal
      TYPE_VALUES = {
        "string" => ->(n) { %("test #{n}") }, "text" => ->(n) { %("test #{n}") },
        "integer" => ->(_) { "42" }, "int" => ->(_) { "42" }, "number" => ->(_) { "42" },
        "float" => ->(_) { "3.14" }, "decimal" => ->(_) { "3.14" },
        "boolean" => ->(_) { "true" }, "bool" => ->(_) { "true" },
        "array" => ->(_) { "[]" }, "list" => ->(_) { "[]" },
        "hash" => ->(_) { "{}" }, "object" => ->(_) { "{}" }, "dict" => ->(_) { "{}" }
      }.freeze

      def generate_value_for_type(type, name = "value")
        TYPE_VALUES.fetch(type&.to_s&.downcase, ->(_) { %("test") }).call(name)
      end

      # Create a mock that simulates multi-step reasoning.
      #
      # @param steps [Integer] Number of steps before final answer
      # @param final_answer [String] The final answer
      # @return [MockModel] Configured mock
      def mock_for_steps(steps:, final_answer: "Done")
        mock = MockModel.new

        (steps - 1).times do |i|
          mock.queue_code_action("step_#{i + 1} = 'processing'")
        end

        mock.queue_final_answer(final_answer)
        mock
      end

      private

      def resolve_tool(tool_name)
        # Try to find tool in common places
        return nil unless defined?(Smolagents::Tools)

        # Check if it's a class constant
        const_name = tool_name.to_s.split("_").map(&:capitalize).join
        Smolagents::Tools.const_get(const_name).new if Smolagents::Tools.const_defined?(const_name)
      rescue NameError
        nil
      end
    end
  end
end
