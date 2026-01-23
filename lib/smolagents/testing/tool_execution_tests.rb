# frozen_string_literal: true

module Smolagents
  module Testing
    # Granular tool execution tests that integrate with the Capabilities registry.
    #
    # Tests the critical path: model generates code -> tools execute -> model uses results.
    # Each test isolates a specific behavior to identify exactly where models struggle.
    #
    # @example Run all tool execution tests via the fluent DSL
    #   Smolagents.test_suite(:tool_execution)
    #     .requires(:variable_persistence)
    #     .requires(:sequential_tools)
    #     .reliability(runs: 3, threshold: 0.67)
    #     .run(model)
    #
    # @example Run a specific test
    #   Smolagents.test(:model)
    #     .from(Capabilities.get(:store_and_retrieve))
    #     .run(model)
    #
    module ToolExecutionTests
      # Tool definitions used by tests - created once and reused
      module TestTools
        module_function

        def echo = @echo ||= build_echo
        def add = @add ||= build_add
        def multiply = @multiply ||= build_multiply
        def get_data = @get_data ||= build_get_data
        def failing = @failing ||= build_failing
        def strict_add = @strict_add ||= build_strict_add

        def build_echo
          Tools.define_tool(
            "echo",
            description: "Echoes back the message",
            inputs: { message: { type: "string", description: "Message to echo" } },
            output_type: "string"
          ) { |message:| message }
        end

        def build_add
          Tools.define_tool(
            "add",
            description: "Adds two numbers",
            inputs: {
              a: { type: "integer", description: "First number" },
              b: { type: "integer", description: "Second number" }
            },
            output_type: "integer"
          ) { |a:, b:| a + b }
        end

        def build_multiply
          Tools.define_tool(
            "multiply",
            description: "Multiplies two numbers",
            inputs: {
              a: { type: "integer", description: "First number" },
              b: { type: "integer", description: "Second number" }
            },
            output_type: "integer"
          ) { |a:, b:| a * b }
        end

        def build_get_data
          Tools.define_tool(
            "get_data",
            description: "Returns structured data with name, count, and active fields",
            inputs: {},
            output_type: "object"
          ) { { name: "TestItem", count: 42, active: true } }
        end

        def build_failing
          Tools.define_tool(
            "failing_tool",
            description: "A tool that always fails (for testing error handling)",
            inputs: {},
            output_type: "string"
          ) { raise StandardError, "Tool intentionally failed" }
        end

        def build_strict_add
          Tools.define_tool(
            "strict_add",
            description: "Adds two numbers (integers only, fails on strings)",
            inputs: {
              a: { type: "integer", description: "First number (must be integer)" },
              b: { type: "integer", description: "Second number (must be integer)" }
            },
            output_type: "integer"
          ) do |a:, b:|
            raise ArgumentError, "Both arguments must be integers" unless a.is_a?(Integer) && b.is_a?(Integer)

            a + b
          end
        end
      end

      # Register all tool execution capabilities
      # @api private
      def self.register_capabilities!
        register_variable_persistence_tests
        register_sequential_tool_tests
        register_parallel_tool_tests
        register_error_recovery_tests
        register_result_synthesis_tests
      end

      def self.register_variable_persistence_tests
        # Variable Persistence: Can the model store with @var and retrieve later?
        Capabilities.register(:variable_persistence,
                              name: "store_and_retrieve",
                              task: <<~TASK.strip,
                                Step 1: Call add(a: 10, b: 20) and store the result in @sum using @sum = add(...)
                                Step 2: Return @sum with final_answer
                              TASK
                              tools: [:add],
                              validator: Validators.contains("30"),
                              max_steps: 4, timeout: 60)

        Capabilities.register(:variable_persistence,
                              name: "accumulate_state",
                              task: <<~TASK.strip,
                                Use multiple steps:
                                Step 1: @a = add(a: 5, b: 5)
                                Step 2: @b = add(a: @a, b: 10)
                                Step 3: final_answer with @b
                              TASK
                              tools: [:add],
                              validator: Validators.contains("20"),
                              max_steps: 5, timeout: 60)
      end

      def self.register_sequential_tool_tests
        # Sequential Tools: Can the model chain tool calls based on previous results?
        Capabilities.register(:sequential_tools,
                              name: "chain_two_tools",
                              task: "First add 10 + 10, then multiply that result by 2. Return the final number.",
                              tools: %i[add multiply],
                              validator: Validators.contains("40"),
                              max_steps: 5, timeout: 60)

        Capabilities.register(:sequential_tools,
                              name: "conditional_chain",
                              task: <<~TASK.strip,
                                Get the data using get_data. If the count field is greater than 0,
                                add the count to 100 and return that. Otherwise return 0.
                              TASK
                              tools: %i[get_data add],
                              validator: Validators.contains("142"),
                              max_steps: 5, timeout: 60)
      end

      def self.register_parallel_tool_tests
        # Parallel Tools: Can the model batch multiple independent calls?
        Capabilities.register(:parallel_tools,
                              name: "batch_independent_calls",
                              task: <<~TASK.strip,
                                In ONE code block, call add(a: 1, b: 2) and add(a: 3, b: 4).
                                Store results in @x and @y. Then return @x + @y with final_answer.
                              TASK
                              tools: [:add],
                              validator: Validators.contains("10"),
                              max_steps: 3, timeout: 60)
      end

      def self.register_error_recovery_tests
        # Error Recovery: What happens when a tool fails?
        Capabilities.register(:error_recovery,
                              name: "handle_tool_error",
                              task: <<~TASK.strip,
                                Try calling failing_tool(). When it fails, catch the error and
                                return "recovered" with final_answer instead.
                              TASK
                              tools: [:failing_tool],
                              validator: Validators.any_of(
                                Validators.contains("recovered"),
                                Validators.contains("error")
                              ),
                              max_steps: 4, timeout: 60)

        Capabilities.register(:error_recovery,
                              name: "retry_with_correction",
                              task: <<~TASK.strip,
                                Call strict_add with a: "five", b: 3. This will fail because "five" is not a number.
                                Correct your input and try again with a: 5, b: 3. Return the result.
                              TASK
                              tools: [:strict_add],
                              validator: Validators.contains("8"),
                              max_steps: 5, timeout: 60)
      end

      def self.register_result_synthesis_tests
        # Result Synthesis: Can the model synthesize results into a coherent answer?
        Capabilities.register(:result_synthesis,
                              name: "synthesize_computation",
                              task: <<~TASK.strip,
                                Compute: (10 + 5) * 2
                                Use add for addition, multiply for multiplication.
                                Show your work and return the final answer.
                              TASK
                              tools: %i[add multiply],
                              validator: Validators.contains("30"),
                              max_steps: 5, timeout: 60)
      end

      # All tool execution capabilities
      CAPABILITIES = %i[
        variable_persistence
        sequential_tools
        parallel_tools
        error_recovery
        result_synthesis
      ].freeze

      # Get all tests for tool execution
      def self.all_tests
        CAPABILITIES.flat_map { |cap| Capabilities.for_capability(cap) }
      end

      # Get the tools needed for a test case
      #
      # @param test_case [TestCase] The test case
      # @return [Array<Tool>] Tool instances
      def self.tools_for(test_case)
        test_case.tools.map { |name| tool_instance(name) }.compact + [Tools::FinalAnswerTool.new]
      end

      # Get a tool instance by name
      #
      # @param name [Symbol, String] Tool name
      # @return [Tool, nil] Tool instance or nil
      def self.tool_instance(name)
        case name.to_sym
        when :echo then TestTools.echo
        when :add then TestTools.add
        when :multiply then TestTools.multiply
        when :get_data then TestTools.get_data
        when :failing_tool then TestTools.failing
        when :strict_add then TestTools.strict_add
        else
          # Try to resolve from global config
          Smolagents.configuration.tools.resolve(name)
        end
      end
    end

    # Register tool execution capabilities on load
    ToolExecutionTests.register_capabilities!
  end
end
