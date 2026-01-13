module Smolagents
  module Testing
    # Immutable result from a single benchmark test.
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
      def self.success(model_id:, test_name:, level:, duration:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: true, duration:, tokens:, steps:, error: nil, metadata:)
      end

      def self.failure(model_id:, test_name:, level:, duration:, error:, tokens: nil, steps: nil, metadata: {})
        new(model_id:, test_name:, level:, passed: false, duration:, tokens:, steps:, error:, metadata:)
      end

      def passed? = passed
      def failed? = !passed

      def tokens_per_second
        return nil unless tokens && duration && duration.positive?

        tokens.total_tokens / duration
      end

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
      def self.from_results(model_id, results, capabilities: nil)
        passed_levels = results.filter_map { |r| r.level if r.passed? }
        max_level = passed_levels.max || 0

        total_dur = results.sum(&:duration)
        total_tok = results
                    .filter_map(&:tokens)
                    .sum(TokenUsage.zero)

        pass_count = results.count(&:passed?)
        rate = results.empty? ? 0.0 : pass_count.to_f / results.size

        avg_tps = total_dur.positive? ? total_tok.total_tokens / total_dur : 0.0

        new(
          model_id:,
          capabilities:,
          results:,
          max_level_passed: max_level,
          total_duration: total_dur,
          total_tokens: total_tok,
          pass_rate: rate,
          avg_tokens_per_second: avg_tps
        )
      end

      def level_badge
        case max_level_passed
        when 0 then "INCOMPATIBLE"
        when 1 then "BASIC"
        when 2 then "FORMAT_OK"
        when 3 then "TOOL_CAPABLE"
        when 4 then "MULTI_STEP"
        when 5 then "REASONING"
        when 6 then "VISION"
        else "UNKNOWN"
        end
      end

      # rubocop:disable Metrics/AbcSize
      def report
        lines = []
        lines << ("=" * 70)
        lines << "Model: #{model_id}"

        if capabilities
          lines << "Architecture: #{capabilities.architecture} | Params: #{capabilities.param_count_str} | Context: #{capabilities.context_length}"
          lines << "Capabilities: #{capability_flags}"
        end

        lines << ("-" * 70)
        lines << "Rating: #{level_badge} (Level #{max_level_passed})"
        lines << "Pass Rate: #{(pass_rate * 100).round(1)}% (#{results.count(&:passed?)}/#{results.size})"
        lines << "Total Time: #{total_duration.round(2)}s | Avg Throughput: #{avg_tokens_per_second.round(0)} tok/s"
        lines << "Total Tokens: #{total_tokens.total_tokens}" if total_tokens.total_tokens.positive?
        lines << ("-" * 70)
        lines << "#{"TEST".ljust(30)}| #{"TIME".rjust(8)} | #{"THROUGHPUT".rjust(12)}"
        lines << ("-" * 70)
        results.each { |r| lines << r.to_row }
        lines << ("=" * 70)
        lines.join("\n")
      end
      # rubocop:enable Metrics/AbcSize

      def capability_flags
        flags = []
        flags << "tool_use" if capabilities&.tool_use?
        flags << "vision" if capabilities&.vision?
        flags << "#{capabilities.reasoning}_reasoning" if capabilities
        flags.join(", ")
      end

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
