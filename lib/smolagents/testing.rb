require_relative "testing/model_capabilities"
require_relative "testing/benchmark_result"
require_relative "testing/model_benchmark"

module Smolagents
  # Testing and benchmarking infrastructure for model evaluation.
  #
  # This module provides tools for evaluating model compatibility with
  # the smolagents framework. It includes:
  #
  # - ModelCapabilities: Describes what a model can do
  # - ModelRegistry: Discovers and catalogs available models
  # - ModelBenchmark: Runs tiered tests to evaluate compatibility
  # - BenchmarkResult/Summary: Captures and reports test results
  #
  # @example Quick model evaluation
  #   # Discover available models
  #   registry = Testing::ModelRegistry.from_lm_studio
  #
  #   # Run benchmarks
  #   benchmark = Testing::ModelBenchmark.new
  #   summary = benchmark.run("gpt-oss-20b")
  #   puts summary.report
  #
  # @example Benchmark all models
  #   registry = Testing::ModelRegistry.from_lm_studio
  #   benchmark = Testing::ModelBenchmark.new
  #
  #   summaries = benchmark.run_all_models(registry)
  #   summaries.each { |id, s| puts s.report }
  #
  # @example Filter models by capability
  #   registry = Testing::ModelRegistry.from_lm_studio
  #
  #   # Only test models with tool use
  #   tool_models = registry.with_tool_use
  #
  #   # Only test fast models
  #   fast_models = registry.fast_models
  #
  module Testing
    class << self
      # Quick benchmark of a single model.
      #
      # @param model_id [String] Model ID to test
      # @param base_url [String] LM Studio base URL
      # @param levels [Range] Test levels to run
      # @return [BenchmarkSummary]
      def benchmark(model_id, base_url: "http://localhost:1234/v1", levels: 1..5)
        bench = ModelBenchmark.new(base_url:)
        bench.run(model_id, levels:)
      end

      # Discover models from LM Studio.
      #
      # @param base_url [String] LM Studio base URL
      # @return [ModelRegistry]
      def discover_models(base_url: "http://localhost:1234")
        ModelRegistry.from_lm_studio(base_url)
      end

      # Print a comparison table of all models.
      #
      # @param summaries [Hash{String => BenchmarkSummary}]
      # rubocop:disable Metrics/AbcSize
      def comparison_table(summaries)
        lines = []
        lines << ("=" * 100)
        lines << "MODEL COMPATIBILITY MATRIX"
        lines << ("=" * 100)
        header = "#{"Model".ljust(26)} | #{"Params".rjust(6)} | #{"Level".ljust(12)} | #{"Pass".rjust(6)} | #{"Time".rjust(8)} | #{"Tok/s".rjust(8)} | Arch"
        lines << header
        lines << ("-" * 100)

        summaries.sort_by { |_, s| [-s.max_level_passed, -s.avg_tokens_per_second] }.each do |id, summary|
          caps = summary.capabilities
          params = caps&.param_count_str || "?"
          rate = "#{(summary.pass_rate * 100).round(0)}%"
          time = "#{summary.total_duration.round(1)}s"
          tps = summary.avg_tokens_per_second.round(0).to_s
          arch = caps&.architecture&.to_s || "?"

          lines << "#{id.ljust(26)} | #{params.rjust(6)} | #{summary.level_badge.ljust(12)} | #{rate.rjust(6)} | #{time.rjust(8)} | #{tps.rjust(8)} | #{arch}"
        end

        lines << ("=" * 100)
        lines << ""
        lines << "Legend: Level indicates highest test tier passed"
        lines << "  INCOMPATIBLE - Cannot respond coherently"
        lines << "  BASIC        - Can respond, but not in correct format"
        lines << "  FORMAT_OK    - Generates proper Ruby code blocks"
        lines << "  TOOL_CAPABLE - Can call tools correctly"
        lines << "  MULTI_STEP   - Can complete multi-step tasks"
        lines << "  REASONING    - Can handle complex reasoning tasks"
        lines.join("\n")
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
