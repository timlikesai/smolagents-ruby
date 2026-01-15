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

      COL_WIDTHS = { model: 26, params: 6, level: 12, pass: 6, time: 8, toks: 8 }.freeze
      LEGEND = [
        "Legend: Level indicates highest test tier passed",
        "  INCOMPATIBLE - Cannot respond coherently", "  BASIC        - Can respond, but not in correct format",
        "  FORMAT_OK    - Generates proper Ruby code blocks", "  TOOL_CAPABLE - Can call tools correctly",
        "  MULTI_STEP   - Can complete multi-step tasks", "  REASONING    - Can handle complex reasoning"
      ].freeze

      # Print a comparison table of all models.
      #
      # @param summaries [Hash{String => BenchmarkSummary}]
      def comparison_table(summaries)
        sorted = summaries.sort_by { |_, s| [-s.max_level_passed, -s.avg_tokens_per_second] }
        [table_header, *sorted.map { |id, s| table_row(id, s) }, table_footer].join("\n")
      end

      private

      def table_header
        ["=" * 100, "MODEL COMPATIBILITY MATRIX", "=" * 100, header_columns.join(" | "), "-" * 100].join("\n")
      end

      def header_columns
        w = COL_WIDTHS
        ["Model".ljust(w[:model]), "Params".rjust(w[:params]), "Level".ljust(w[:level]),
         "Pass".rjust(w[:pass]), "Time".rjust(w[:time]), "Tok/s".rjust(w[:toks]), "Arch"]
      end

      def table_row(id, summary)
        row_values(id, summary).join(" | ")
      end

      def row_values(id, summary)
        [
          format_model_col(id, summary),
          format_summary_cols(summary),
          summary.capabilities&.architecture || "?"
        ].flatten
      end

      def format_model_col(id, summary)
        w = COL_WIDTHS
        caps = summary.capabilities
        [id.ljust(w[:model]), (caps&.param_count_str || "?").rjust(w[:params])]
      end

      def format_summary_cols(summary)
        [format_level_col(summary), format_pass_col(summary), format_time_col(summary), format_toks_col(summary)]
      end

      def format_level_col(summary) = summary.level_badge.ljust(COL_WIDTHS[:level])
      def format_pass_col(summary) = format("%d%%", summary.pass_rate * 100).rjust(COL_WIDTHS[:pass])
      def format_time_col(summary) = format("%.1fs", summary.total_duration).rjust(COL_WIDTHS[:time])
      def format_toks_col(summary) = summary.avg_tokens_per_second.round(0).to_s.rjust(COL_WIDTHS[:toks])

      def table_footer = (["=" * 100, ""] + LEGEND).join("\n")
    end
  end
end
