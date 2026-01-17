module Smolagents
  module Testing
    # Auto-generate test cases from tool definitions.
    #
    # Tools already have schemas with inputs, descriptions, and output types.
    # This module uses that metadata to automatically generate test cases.
    #
    # @example Generate tests for a single tool
    #   tests = AutoGen.tests_for_tool(MyTool.new)
    #   tests.each { |tc| puts tc.task }
    #
    # @example Generate tests for all registered tools
    #   tests = AutoGen.all_tool_tests
    module AutoGen
      extend self

      # Generate test cases from a tool's schema.
      #
      # Creates tests for:
      # - Basic tool invocation
      # - Each required input parameter
      #
      # @param tool [Tool] The tool to generate tests for
      # @return [Array<TestCase>] Generated test cases
      def tests_for_tool(tool)
        [
          basic_invocation_test(tool),
          *input_parameter_tests(tool)
        ].compact
      end

      # Generate tests for multiple tools.
      #
      # @param tools [Array<Tool>] Tools to generate tests for
      # @return [Array<TestCase>] All generated test cases
      def tests_for_tools(tools)
        tools.flat_map { |tool| tests_for_tool(tool) }
      end

      # Generate a test task prompt from tool metadata.
      #
      # @param tool [Tool] The tool
      # @param input_name [Symbol, nil] Specific input to test
      # @return [String] Task prompt
      def generate_task_prompt(tool, input_name: nil)
        if input_name
          spec = tool.inputs[input_name.to_s] || tool.inputs[input_name]
          "Use the #{tool.name} tool. Provide a value for #{input_name}: #{spec&.dig(:description) || "a value"}"
        else
          "Use the #{tool.name} tool to #{tool.description.split(".").first.downcase}"
        end
      end

      # Generate a validator that checks tool was called.
      #
      # @param tool_name [String, Symbol] Name of the tool
      # @return [Proc] Validator proc
      def tool_call_validator(tool_name)
        Validators.any_of(
          Validators.calls_tool(tool_name.to_s),
          Validators.matches(/#{tool_name}/i)
        )
      end

      private

      def basic_invocation_test(tool)
        TestCase.new(
          name: "#{tool.name}_basic_invocation",
          capability: :tool_use,
          task: generate_task_prompt(tool),
          tools: [tool.name.to_sym],
          validator: tool_call_validator(tool.name),
          max_steps: 5,
          timeout: 60
        )
      end

      def input_parameter_tests(tool)
        return [] unless tool.respond_to?(:inputs) && tool.inputs.is_a?(Hash)

        tool.inputs.filter_map { |name, spec| build_input_test(tool, name, spec) }
      end

      def build_input_test(tool, name, spec)
        return unless spec.is_a?(Hash) && spec[:required] != false

        TestCase.new(
          name: "#{tool.name}_with_#{name}", capability: :tool_use, task: generate_task_prompt(tool, input_name: name),
          tools: [tool.name.to_sym], validator: tool_call_validator(tool.name), max_steps: 5, timeout: 60
        )
      end
    end
  end
end
