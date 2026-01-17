module Smolagents
  module Testing
    # Aggregated results from multiple test executions (for reliability testing).
    TestRun = Data.define(:test_case, :results, :threshold) do
      def initialize(test_case:, results:, threshold: 1.0)
        super
      end

      def pass_rate = results.count(&:passed).to_f / results.size
      def passed? = pass_rate >= threshold
      def failed? = !passed?

      def avg_duration = results.sum(&:duration) / results.size
      def avg_steps = results.sum(&:steps).to_f / results.size
      def avg_tokens = results.sum(&:tokens).to_f / results.size

      def p50_duration = percentile(results.map(&:duration), 50)
      def p95_duration = percentile(results.map(&:duration), 95)
      def p99_duration = percentile(results.map(&:duration), 99)

      def summary
        { test_case: test_case.name, runs: results.size, pass_rate:, threshold:,
          avg_duration:, avg_steps:, avg_tokens:, p50_duration:, p99_duration: }
      end

      def to_h = summary
      def deconstruct_keys(_) = summary

      private

      def percentile(values, pct)
        sorted = values.sort
        idx = (pct / 100.0 * (sorted.size - 1)).round
        sorted[idx]
      end
    end
  end
end
