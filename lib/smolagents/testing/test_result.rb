module Smolagents
  module Testing
    # Immutable result from a single test execution.
    #
    # Captures the outcome of running a TestCase on a model, including pass/fail
    # status, output, timing, token usage, and error details for analysis.
    #
    # @example Recording a successful test result
    #   result = TestResult.new(
    #     test_case: test_case,
    #     passed: true,
    #     output: "Ruby 4.0 was released in 2024",
    #     duration: 2.34,
    #     steps: 2,
    #     tokens: 150
    #   )
    #
    # @example Recording a failed test result
    #   result = TestResult.new(
    #     test_case: test_case,
    #     passed: false,
    #     error: RuntimeError.new("Model timeout"),
    #     duration: 30.0,
    #     steps: 5
    #   )
    #
    # @see TestCase
    TestResult = Data.define(:test_case, :passed, :output, :error, :duration, :steps, :tokens, :partial_score,
                             :raw_steps) do
      # Creates a new TestResult with default values.
      #
      # @param test_case [TestCase] The test case that was executed
      # @param passed [Boolean] Whether the test passed validation
      # @param output [String, nil] The agent's final output (default: nil)
      # @param error [Exception, nil] Any error that occurred (default: nil)
      # @param duration [Numeric] Execution time in seconds (default: 0)
      # @param steps [Integer] Number of steps taken (default: 0)
      # @param tokens [Integer] Total tokens consumed (default: 0)
      # @param partial_score [Float, nil] Partial credit score 0.0-1.0 (default: nil)
      # @param raw_steps [Array] Raw step objects from execution (default: [])
      def initialize(test_case:, passed:, output: nil, error: nil, duration: 0, steps: 0, tokens: 0,
                     partial_score: nil, raw_steps: [])
        super
      end

      # Check if test passed without errors.
      # @return [Boolean] True if passed and no error occurred
      def success? = passed && error.nil?

      # Check if test failed.
      # @return [Boolean] True if test did not pass
      def failure? = !passed

      # Calculate step efficiency (lower is better).
      #
      # Returns the fraction of max_steps used. A value of 0.3 means the test
      # completed in 30% of the allowed steps, leaving 70% efficiency margin.
      #
      # @return [Float] Efficiency score from 0.0 to 1.0, or 0.0 if failed
      def efficiency
        return 0.0 unless passed
        return 0.0 unless test_case.max_steps.positive?

        (1.0 - (steps.to_f / test_case.max_steps)).clamp(0, 1)
      end

      # Calculate average tokens consumed per step.
      # @return [Float] Tokens per step, or 0.0 if no steps taken
      def tokens_per_step = steps.positive? ? tokens.to_f / steps : 0.0

      # Convert to a serializable hash representation.
      # @return [Hash] Hash with all fields except raw_steps
      def to_h
        {
          test_case: test_case.name,
          passed:,
          output:,
          error: error&.message,
          duration:,
          steps:,
          tokens:,
          efficiency:
        }
      end

      # Enable pattern matching with hash patterns.
      # @param _ [Array, nil] Ignored
      # @return [Hash] Hash representation for pattern matching
      def deconstruct_keys(_) = to_h
    end
  end
end
