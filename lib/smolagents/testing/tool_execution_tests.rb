require_relative "test_tools"

module Smolagents
  module Testing
    # Granular tool execution tests that integrate with the Capabilities registry.
    module ToolExecutionTests
      CAPABILITIES = %i[
        variable_persistence sequential_tools parallel_tools error_recovery result_synthesis
      ].freeze

      class << self
        def register_capabilities!
          register_variable_persistence_tests
          register_sequential_tool_tests
          register_parallel_tool_tests
          register_error_recovery_tests
          register_result_synthesis_tests
        end

        def all_tests = CAPABILITIES.flat_map { |cap| Capabilities.for_capability(cap) }

        def tools_for(test_case)
          test_case.tools.filter_map { |name| tool_instance(name) } + [Tools::FinalAnswerTool.new]
        end

        def tool_instance(name)
          TOOL_MAP[name.to_sym]
        end

        private

        def register_variable_persistence_tests
          reg(:variable_persistence, "store_and_retrieve",
              "Call add(a: 10, b: 20), store in @sum, return with final_answer",
              [:add], "30", 4)
          reg(:variable_persistence, "accumulate_state",
              "Step 1: @a = add(a: 5, b: 5). Step 2: @b = add(a: @a, b: 10). Step 3: final_answer(@b)",
              [:add], "20", 5)
        end

        def register_sequential_tool_tests
          reg(:sequential_tools, "chain_two_tools",
              "Add 10 + 10, then multiply that result by 2. Return the final number.",
              %i[add multiply], "40", 5)
          reg(:sequential_tools, "conditional_chain",
              "Get data using get_data. If count > 0, add it to 100 and return that.",
              %i[get_data add], "142", 5)
        end

        def register_parallel_tool_tests
          reg(:parallel_tools, "batch_independent_calls",
              "In ONE code block: @x = add(a: 1, b: 2), @y = add(a: 3, b: 4). Return @x + @y.",
              [:add], "10", 3)
        end

        def register_error_recovery_tests
          register_error_handling_test
          reg(:error_recovery, "retry_with_correction",
              "Call strict_add(a: \"five\", b: 3). It fails. Retry with a: 5, b: 3.",
              [:strict_add], "8", 5)
        end

        def register_error_handling_test
          validator = Validators.any_of(
            Validators.contains("recovered"), Validators.contains("error")
          )
          Capabilities.register(:error_recovery, name: "handle_tool_error",
                                                 task: "Call failing_tool(). When it fails, return \"recovered\".",
                                                 tools: [:failing_tool], validator:, max_steps: 4, timeout: 60)
        end

        def register_result_synthesis_tests
          reg(:result_synthesis, "synthesize_computation",
              "Compute: (10 + 5) * 2 using add and multiply. Return the final answer.",
              %i[add multiply], "30", 5)
        end

        # rubocop:disable Metrics/ParameterLists -- intentionally compact registration helper
        def reg(cap, name, task, tools, expected, max_steps, timeout = 60)
          Capabilities.register(cap, name:, task:, tools:,
                                     validator: Validators.contains(expected), max_steps:, timeout:)
        end
        # rubocop:enable Metrics/ParameterLists
      end

      TOOL_MAP = {
        echo: TestTools.echo,
        add: TestTools.add,
        multiply: TestTools.multiply,
        get_data: TestTools.data,
        failing_tool: TestTools.failing,
        strict_add: TestTools.strict_add
      }.freeze
    end

    ToolExecutionTests.register_capabilities!

    # Re-register after Capabilities.reset! is called
    Capabilities.on_reset { ToolExecutionTests.register_capabilities! }
  end
end
