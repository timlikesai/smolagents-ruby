module Smolagents
  module Testing
    # Runs test cases against models and collects results.
    #
    # TestRunner executes a TestCase against a model, optionally multiple times
    # for reliability testing. It handles timing, error capture, and result
    # aggregation into a TestRun.
    #
    # @example Single execution
    #   runner = TestRunner.new(test_case, model)
    #   result = runner.run
    #
    # @example Reliability testing
    #   runner = TestRunner.new(test_case, model)
    #   run = runner.run(times: 5, threshold: 0.8)
    #   puts run.pass_rate  # => 0.8
    #
    # @see TestCase
    # @see TestResult
    # @see TestRun
    class TestRunner
      # @return [TestCase] The test case being run
      attr_reader :test_case

      # @return [Models::Model] The model being tested
      attr_reader :model

      # Creates a new TestRunner.
      #
      # @param test_case [TestCase] The test case to execute
      # @param model [Models::Model] The model to test against
      def initialize(test_case, model)
        @test_case = test_case
        @model = model
      end

      # Runs the test case.
      #
      # @param times [Integer] Number of times to run (default: 1)
      # @param threshold [Float] Required pass rate (default: 1.0)
      # @return [TestRun] Aggregated results
      def run(times: 1, threshold: 1.0)
        results = Array.new(times) { run_single }
        TestRun.new(test_case: @test_case, results:, threshold:)
      end

      private

      def run_single
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        execution = safe_execute
        build_test_result(execution, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time)
      end

      def safe_execute
        result = real_model? ? execute_with_agent : { output: "placeholder", steps: 0, tokens: 0 }
        { **result, passed: validate_output(result[:output]), error: nil }
      rescue StandardError => e
        { output: nil, steps: 0, tokens: 0, passed: false, error: e }
      end

      def real_model? = @model.respond_to?(:call) || @model.is_a?(Models::Model)

      def build_test_result(exec, duration)
        TestResult.new(test_case: @test_case, passed: exec[:passed], output: exec[:output],
                       error: exec[:error], duration:, steps: exec[:steps], tokens: exec[:tokens])
      end

      def execute_with_agent
        agent = Agents::Agent.new(tools: resolve_tools, model: @model, max_steps: @test_case.max_steps)
        run_result = agent.run(@test_case.task)
        { output: run_result.output, steps: run_result.steps&.size || 0, tokens: extract_tokens(run_result) }
      end

      def resolve_tools
        @test_case.tools.filter_map do |tool_name|
          Smolagents.configuration.tools.resolve(tool_name)
        end
      end

      def validate_output(output)
        return true unless @test_case.validator

        @test_case.validator.call(output)
      end

      def extract_tokens(run_result)
        return 0 unless run_result.respond_to?(:steps) && run_result.steps

        run_result.steps.sum { |s| s.respond_to?(:tokens) ? s.tokens.to_i : 0 }
      end
    end
  end
end
