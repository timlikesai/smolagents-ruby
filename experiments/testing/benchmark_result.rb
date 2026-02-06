# Benchmark result types for model evaluation.
#
# Split into focused modules:
# - result.rb: BenchmarkResult data structure
# - formatting.rb: Report formatting for summaries
# - summary.rb: BenchmarkSummary with aggregation

require_relative "benchmark_result/result"
require_relative "benchmark_result/formatting"
require_relative "benchmark_result/summary"
