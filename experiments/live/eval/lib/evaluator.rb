# Evaluator
#
# Runs tests against models and validates expectations.
# Core execution engine for the evaluation framework.

require "timeout"

module LiveExperiments
  module Eval
    class Evaluator
      def initialize(model:, tools: {})
        @model = model
        @tools = tools  # name => tool instance mapping
        reset_circuit_breakers  # Start fresh for eval runs
      end

      # Reset all Stoplight circuit breakers to prevent test pollution.
      # This is critical for eval runs where one model's failures shouldn't
      # affect subsequent models on the same endpoint.
      def reset_circuit_breakers
        return unless defined?(Stoplight)

        data_store = Stoplight.default_data_store
        # Clear all failures from the data store
        data_store.names.each do |name|
          data_store.clear_failures(Stoplight(name).build)
          data_store.clear_state(Stoplight(name).build)
        end
      rescue StandardError
        # Ignore if Stoplight not available or reset fails
      end

      # Run a single test
      def run_test(test)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = execute_test(test)
          duration_ms = elapsed_ms(start)

          validation = validate_result(result, test.expect)

          TestResult.new(
            test_id: test.id,
            test_name: test.name,
            passed: validation[:passed],
            duration_ms:,
            output: truncate(result[:output], 1000),
            error: nil,
            details: validation[:details].merge(
              steps: result[:steps],
              tool_calls: result[:tool_calls],
              code_actions: result[:code_actions],
              raw_outputs: result[:raw_outputs]&.map { |o| truncate(o.to_s, 500) }
            )
          )
        rescue Timeout::Error
          TestResult.new(
            test_id: test.id,
            test_name: test.name,
            passed: false,
            duration_ms: elapsed_ms(start),
            output: nil,
            error: "Timeout after #{test.timeout}s",
            details: {}
          )
        rescue StandardError => e
          TestResult.new(
            test_id: test.id,
            test_name: test.name,
            passed: false,
            duration_ms: elapsed_ms(start),
            output: nil,
            error: "#{e.class}: #{e.message}",
            details: { backtrace: e.backtrace&.first(5) }
          )
        end
      end

      # Run all tests in a suite
      def run_suite(suite, progress: nil)
        # Warm up model first (triggers load if needed)
        warm_up_model

        test_results = suite.tests.map.with_index do |test, idx|
          progress&.call(idx + 1, suite.tests.size, test.name)
          run_test(test)
        end

        build_suite_result(suite, test_results)
      end

      # Send a simple request to ensure model is loaded.
      # Live model loading can take 30-60+ seconds.
      def warm_up_model
        print "    Warming up model (may take a minute if loading)... "
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        message = Smolagents::Types::ChatMessage.user("Say 'ready'")
        Timeout.timeout(120) { @model.generate([message]) }

        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        puts "ready (#{elapsed}ms)"
      rescue Timeout::Error
        puts "TIMEOUT (model may not be available)"
      rescue StandardError => e
        puts "ERROR: #{e.message}"
      end

      private

      def execute_test(test)
        tools = resolve_tools(test.tools)
        agent = build_agent(tools)

        result = Timeout.timeout(test.timeout) { agent.run(test.prompt) }

        {
          output: result.output.to_s,
          steps: result.steps.size,
          tool_calls: extract_tool_calls(result),
          state: result.state,
          code_actions: extract_code_actions(result),
          raw_outputs: extract_raw_outputs(result)
        }
      end

      def extract_code_actions(result)
        result.steps.filter_map do |step|
          step.code_action if step.respond_to?(:code_action) && step.code_action
        end
      end

      def extract_raw_outputs(result)
        result.steps.filter_map do |step|
          next unless step.respond_to?(:model_output_message)

          msg = step.model_output_message
          msg&.content if msg.respond_to?(:content)
        end
      end

      def build_agent(tools)
        builder = Smolagents.agent.model { @model }.max_steps(10)
        tools.each { |t| builder = builder.tools(t) }
        builder.build
      end

      def resolve_tools(tool_names)
        tool_names.map do |name|
          @tools[name] || @tools[name.to_sym] ||
            raise(ArgumentError, "Unknown tool: #{name}")
        end
      end

      def extract_tool_calls(result)
        result.steps.flat_map do |step|
          # Try native tool_calls first (OpenAI API style)
          if step.respond_to?(:tool_calls) && step.tool_calls&.any?
            step.tool_calls.map { |tc| { name: tc.name, arguments: tc.arguments } }
          # Fall back to code_action parsing (agent code execution style)
          elsif step.respond_to?(:code_action) && step.code_action
            extract_from_code_action(step.code_action)
          else
            []
          end
        end
      end

      # Parse tool calls from code_action string
      # Matches patterns like: calculator(expression: "15 * 7")
      def extract_from_code_action(code)
        tool_names = @tools.keys.map(&:to_s)
        calls = []

        tool_names.each do |name|
          # Match tool_name(...) patterns
          code.scan(/#{Regexp.escape(name)}\s*\(([^)]*)\)/) do |args_str|
            calls << { name:, arguments: parse_args(args_str.first) }
          end
        end

        calls
      end

      def parse_args(args_str)
        # Simple parsing: extract key: value pairs
        result = {}
        args_str.scan(/(\w+):\s*("[^"]*"|'[^']*'|\S+)/) do |key, val|
          result[key] = val.gsub(/^["']|["']$/, "")
        end
        result
      end

      def validate_result(result, expect)
        checks = []
        output = result[:output].to_s

        # Content checks
        expect.contains.each do |text|
          checks << check_contains(output, text)
        end

        expect.not_contains.each do |text|
          checks << check_not_contains(output, text)
        end

        # Tool call checks
        checks << check_tool_called(result[:tool_calls], expect.tool_called) if expect.tool_called

        # Step count checks
        checks << check_min_steps(result[:steps], expect.min_steps) if expect.min_steps
        checks << check_max_steps(result[:steps], expect.max_steps) if expect.max_steps

        {
          passed: checks.all? { |c| c[:passed] },
          details: { checks: }
        }
      end

      def check_contains(output, text)
        passed = output.downcase.include?(text.downcase)
        { check: "contains", expected: text, passed:, actual: passed ? "found" : "not found" }
      end

      def check_not_contains(output, text)
        passed = !output.downcase.include?(text.downcase)
        { check: "not_contains", expected: text, passed:, actual: passed ? "not found" : "found" }
      end

      def check_tool_called(tool_calls, expected_tool)
        passed = tool_calls.any? { |tc| tc[:name] == expected_tool }
        { check: "tool_called", expected: expected_tool, passed:,
          actual: tool_calls.map { |tc| tc[:name] }.join(", ") }
      end

      def check_min_steps(steps, min)
        passed = steps >= min
        { check: "min_steps", expected: min, passed:, actual: steps }
      end

      def check_max_steps(steps, max)
        passed = steps <= max
        { check: "max_steps", expected: max, passed:, actual: steps }
      end

      def build_suite_result(suite, test_results)
        passed = test_results.count(&:passed)
        failed = test_results.count { |r| !r.passed && r.error.nil? }
        errored = test_results.count { |r| r.error }
        durations = test_results.map(&:duration_ms)

        SuiteResult.new(
          model_id: @model.model_id,
          suite_name: suite.name,
          timestamp: Time.now,
          summary: ResultSummary.new(
            total: test_results.size,
            passed:,
            failed: failed + errored,
            skipped: 0,
            pass_rate: (passed.to_f / test_results.size).round(3),
            avg_duration_ms: (durations.sum / durations.size.to_f).round
          ),
          test_results:,
          metadata: { tier: suite.tier, description: suite.description }
        )
      end

      def elapsed_ms(start)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
      end

      def truncate(str, max)
        str.length > max ? "#{str[0...max]}..." : str
      end
    end
  end
end
