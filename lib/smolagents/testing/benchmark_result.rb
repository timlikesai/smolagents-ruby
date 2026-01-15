module Smolagents
  module Testing
    LEVEL_BADGES = {
      0 => "INCOMPATIBLE", 1 => "BASIC", 2 => "FORMAT_OK",
      3 => "TOOL_CAPABLE", 4 => "MULTI_STEP", 5 => "REASONING", 6 => "VISION"
    }.freeze
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
      # @param duration [Float] Time taken to run test in seconds
      # @param tokens [TokenUsage, nil] Token usage details (input + output)
      # @param steps [Integer, nil] Number of steps/iterations taken
      # @param metadata [Hash] Optional additional data for analysis
      # @return [BenchmarkResult] Success result instance
      #
      # @example
      #   result = BenchmarkResult.success(
      #     model_id: "gpt-oss-20b",
      #     test_name: "single_tool_call",
      #     level: 3,
      #     duration: 1.5,
      #     tokens: TokenUsage.new(input_tokens: 100, output_tokens: 50),
      #     steps: 2
      #   )
      def self.success(model_id:, test_name:, level:, duration:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: true, duration:, tokens:, steps:, error: nil, metadata:)
      end

      # Create a failed test result.
      #
      # @param model_id [String] Model ID that was tested
      # @param test_name [String] Name of the test case
      # @param level [Integer] Benchmark level (1-6)
      # @param duration [Float] Time taken before failure in seconds
      # @param error [String] Error message describing the failure
      # @param tokens [TokenUsage, nil] Token usage before failure
      # @param steps [Integer, nil] Number of steps taken before failure
      # @param metadata [Hash] Optional additional data for analysis
      # @return [BenchmarkResult] Failure result instance
      #
      # @example
      #   result = BenchmarkResult.failure(
      #     model_id: "gpt-oss-20b",
      #     test_name: "basic_response",
      #     level: 1,
      #     duration: 2.0,
      #     error: "No '4' found in response"
      #   )
      def self.failure(model_id:, test_name:, level:, duration:, error:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: false, duration:, tokens:, steps:, error:, metadata:)
      end

      # Check if test passed.
      #
      # @return [Boolean] True if test passed
      def passed? = passed

      # Check if test failed.
      #
      # @return [Boolean] True if test failed
      def failed? = !passed

      # Calculate throughput in tokens per second.
      #
      # @return [Float, nil] Tokens per second, or nil if no tokens or zero duration
      #
      # @example
      #   result.tokens_per_second # => 75.5
      def tokens_per_second
        return nil unless tokens && duration && duration.positive?

        tokens.total_tokens / duration
      end

      # Format result as a single-line table row for display.
      #
      # Formats as: "PASS | test_name | time | throughput [error]"
      #
      # @return [String] Formatted single-line result
      #
      # @example
      #   puts result.to_row
      #   # => "PASS | single_tool_call      |     1.50s |          75 tok/s"
      def to_row
        status = passed ? "PASS" : "FAIL"
        time = format("%.2fs", duration)
        tps = tokens_per_second ? format("%.0f tok/s", tokens_per_second) : "-"
        err = error ? " (#{error.to_s.slice(0, 40)})" : ""

        "#{status} | #{test_name.ljust(25)} | #{time.rjust(8)} | #{tps.rjust(12)}#{err}"
      end
    end

    # Aggregated results for a model across all tests.
    #
    # Captures all dimensions for analysis:
    # - Compatibility: max_level_passed, pass_rate
    # - Performance: total_duration, tokens_per_second
    # - Efficiency: steps_per_task, tokens_per_step
    #
    # @example Summarizing model performance
    #   summary = BenchmarkSummary.from_results(results)
    #   puts summary.report
    #
    BenchmarkSummary = Data.define(
      :model_id,
      :capabilities, # ModelCapabilities for this model
      :results,
      :max_level_passed,
      :total_duration,
      :total_tokens,
      :pass_rate,
      :avg_tokens_per_second
    ) do
      # Create a summary from a list of benchmark results.
      #
      # Aggregates test results to compute overall metrics:
      # - Maximum level passed (highest successful test level)
      # - Pass rate (fraction of tests that passed)
      # - Total time and tokens across all tests
      # - Average throughput (tokens per second)
      #
      # @param model_id [String] ID of the model being summarized
      # @param results [Array<BenchmarkResult>] All test results for this model
      # @param capabilities [ModelCapabilities, nil] Optional model capability info
      # @return [BenchmarkSummary] Aggregated summary instance
      #
      # @example
      #   results = [result1, result2, result3]
      #   summary = BenchmarkSummary.from_results("gpt-oss-20b", results)
      #   puts "Pass Rate: #{(summary.pass_rate * 100).round(0)}%"
      def self.from_results(model_id, results, capabilities: nil)
        stats = compute_stats(results)
        new(model_id:, capabilities:, results:, **stats)
      end

      def self.compute_stats(results)
        totals = compute_totals(results)
        totals.merge(compute_rates(results, totals))
      end

      def self.compute_totals(results)
        {
          max_level_passed: results.filter_map { it.level if it.passed? }.max || 0,
          total_duration: results.sum(&:duration),
          total_tokens: results.filter_map(&:tokens).sum(TokenUsage.zero)
        }
      end

      def self.compute_rates(results, totals)
        pass_count = results.count(&:passed?)
        dur = totals[:total_duration]
        {
          pass_rate: results.empty? ? 0.0 : pass_count.to_f / results.size,
          avg_tokens_per_second: dur.positive? ? totals[:total_tokens].total_tokens / dur : 0.0
        }
      end

      # Get a human-readable badge for the highest level passed.
      #
      # Maps benchmark levels to capability descriptions:
      # - 0: INCOMPATIBLE - Cannot respond coherently
      # - 1: BASIC - Can respond but not in correct format
      # - 2: FORMAT_OK - Generates proper Ruby code blocks
      # - 3: TOOL_CAPABLE - Can call tools correctly
      # - 4: MULTI_STEP - Can complete multi-step tasks
      # - 5: REASONING - Can handle complex reasoning
      # - 6: VISION - Can process images (VLM only)
      #
      # @return [String] Human-readable capability badge
      #
      # @example
      #   summary.level_badge # => "TOOL_CAPABLE"
      def level_badge = Testing::LEVEL_BADGES.fetch(max_level_passed, "UNKNOWN")

      # Generate a comprehensive human-readable report.
      #
      # Formats a detailed text report including:
      # - Model ID and architecture
      # - Capability flags (tool_use, vision, reasoning level)
      # - Overall rating and pass rate
      # - Performance metrics (time, throughput, tokens)
      # - Detailed results table for each test
      #
      # @return [String] Formatted multi-line report
      #
      # @example
      #   puts summary.report
      #   # ======================================================================
      #   # Model: gpt-oss-20b
      #   # Architecture: transformer | Params: 20.0B | Context: 131072
      #   # Capabilities: tool_use, basic_reasoning
      #   # ------... [more details]
      def report = [report_header, report_metrics, report_table].join("\n")

      private

      def report_header
        lines = ["=" * 70, "Model: #{model_id}"]
        if capabilities
          c = capabilities
          lines << "Architecture: #{c.architecture} | Params: #{c.param_count_str} | Context: #{c.context_length}"
        end
        lines << "Capabilities: #{capability_flags}" if capabilities
        lines.join("\n")
      end

      def report_metrics
        [
          "-" * 70,
          "Rating: #{level_badge} (Level #{max_level_passed})",
          format_pass_rate,
          format_throughput,
          format_total_tokens
        ].compact.join("\n")
      end

      def format_pass_rate
        "Pass Rate: #{(pass_rate * 100).round(1)}% (#{results.count(&:passed?)}/#{results.size})"
      end

      def format_throughput
        "Total Time: #{total_duration.round(2)}s | Avg Throughput: #{avg_tokens_per_second.round(0)} tok/s"
      end

      def format_total_tokens
        "Total Tokens: #{total_tokens.total_tokens}" if total_tokens.total_tokens.positive?
      end

      def report_table
        ["-" * 70, "#{"TEST".ljust(30)}| #{"TIME".rjust(8)} | #{"THROUGHPUT".rjust(12)}", "-" * 70,
         *results.map(&:to_row), "=" * 70].join("\n")
      end

      public

      # Get model capability flags as a comma-separated string.
      #
      # Formats available capabilities based on the model's ModelCapabilities.
      #
      # @return [String] Comma-separated capability flags
      #   (e.g., "tool_use, vision, strong_reasoning")
      #
      # @example
      #   summary.capability_flags # => "tool_use, basic_reasoning"
      def capability_flags
        flags = []
        flags << "tool_use" if capabilities&.tool_use?
        flags << "vision" if capabilities&.vision?
        flags << "#{capabilities.reasoning}_reasoning" if capabilities
        flags.join(", ")
      end

      # Convert summary to a hash representation.
      #
      # Includes all metrics and individual test results for serialization
      # or further processing.
      #
      # @return [Hash] Hash with keys: model_id, capabilities, max_level_passed,
      #   level_badge, total_duration, total_tokens, pass_rate, avg_tokens_per_second, results
      #
      # @example
      #   data = summary.to_h
      #   json = JSON.generate(data)
      def to_h
        {
          model_id:,
          capabilities: capabilities&.to_h,
          max_level_passed:,
          level_badge:,
          total_duration:,
          total_tokens: total_tokens.to_h,
          pass_rate:,
          avg_tokens_per_second:,
          results: results.map do |r|
            { test_name: r.test_name, level: r.level, passed: r.passed, duration: r.duration }
          end
        }
      end
    end
  end
end
