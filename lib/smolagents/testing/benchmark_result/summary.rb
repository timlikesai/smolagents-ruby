module Smolagents
  module Testing
    # Level badges mapping benchmark levels to capability descriptions.
    LEVEL_BADGES = {
      0 => "INCOMPATIBLE", 1 => "BASIC", 2 => "FORMAT_OK",
      3 => "TOOL_CAPABLE", 4 => "MULTI_STEP", 5 => "REASONING", 6 => "VISION"
    }.freeze

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
      :capabilities,
      :results,
      :max_level_passed,
      :total_duration,
      :total_tokens,
      :pass_rate,
      :avg_tokens_per_second
    ) do
      include SummaryFormatting

      # Create a summary from a list of benchmark results.
      #
      # @param model_id [String] ID of the model being summarized
      # @param results [Array<BenchmarkResult>] All test results for this model
      # @param capabilities [ModelCapabilities, nil] Optional model capability info
      # @return [BenchmarkSummary] Aggregated summary instance
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
      # @return [String] Human-readable capability badge
      def level_badge = Testing::LEVEL_BADGES.fetch(max_level_passed, "UNKNOWN")
    end
  end
end
