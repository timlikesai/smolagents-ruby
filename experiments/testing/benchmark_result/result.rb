module Smolagents
  module Testing
    # Immutable result from a single benchmark test.
    #
    # Captures the outcome of running a single test case on a model,
    # including pass/fail status, execution time, token usage, and error details.
    #
    # @example Recording a test result
    #   result = BenchmarkResult.new(
    #     model_id: "gpt-oss-20b",
    #     test_name: "basic_math",
    #     level: 3,
    #     passed: true,
    #     duration: 2.34,
    #     tokens: TokenUsage.new(input_tokens: 150, output_tokens: 50),
    #     steps: 2,
    #     error: nil
    #   )
    #
    BenchmarkResult = Data.define(
      :model_id,
      :test_name,
      :level,
      :passed,
      :duration,
      :tokens,
      :steps,
      :error,
      :metadata
    ) do
      # Create a successful test result.
      #
      # @param model_id [String] Model ID that was tested
      # @param test_name [String] Name of the test case
      # @param level [Integer] Benchmark level (1-6)
      # @param duration [Float] Time taken in seconds
      # @param tokens [TokenUsage, nil] Token usage details
      # @param steps [Integer, nil] Number of steps taken
      # @param metadata [Hash] Optional additional data
      # @return [BenchmarkResult] Success result instance
      def self.success(model_id:, test_name:, level:, duration:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: true, duration:, tokens:, steps:, error: nil, metadata:)
      end

      # Create a failed test result.
      #
      # @param model_id [String] Model ID that was tested
      # @param test_name [String] Name of the test case
      # @param level [Integer] Benchmark level (1-6)
      # @param duration [Float] Time taken before failure
      # @param error [String] Error message describing the failure
      # @param tokens [TokenUsage, nil] Token usage before failure
      # @param steps [Integer, nil] Number of steps taken before failure
      # @param metadata [Hash] Optional additional data
      # @return [BenchmarkResult] Failure result instance
      def self.failure(model_id:, test_name:, level:, duration:, error:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: false, duration:, tokens:, steps:, error:, metadata:)
      end

      # Check if test passed.
      # @return [Boolean] True if test passed
      def passed? = passed

      # Check if test failed.
      # @return [Boolean] True if test failed
      def failed? = !passed

      # Calculate throughput in tokens per second.
      # @return [Float, nil] Tokens per second, or nil if no tokens or zero duration
      def tokens_per_second
        return nil unless tokens && duration && duration.positive?

        tokens.total_tokens / duration
      end

      # Format result as a single-line table row for display.
      # @return [String] Formatted single-line result
      def to_row
        status = passed ? "PASS" : "FAIL"
        time = format("%.2fs", duration)
        tps = tokens_per_second ? format("%.0f tok/s", tokens_per_second) : "-"
        err = error ? " (#{error.to_s.slice(0, 40)})" : ""

        "#{status} | #{test_name.ljust(25)} | #{time.rjust(8)} | #{tps.rjust(12)}#{err}"
      end
    end
  end
end
