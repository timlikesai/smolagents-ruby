# Ensure main library is loaded first for all dependencies
require "smolagents" unless defined?(Smolagents::Models::Model)

require_relative "testing/test_case"
require_relative "testing/test_result"
require_relative "testing/test_run"
require_relative "testing/test_runner"
require_relative "testing/result_store"
require_relative "testing/mock_model"
require_relative "testing/helpers"
require_relative "testing/matchers"
require_relative "testing/validators"
require_relative "testing/capabilities"
require_relative "testing/model_capabilities"
require_relative "testing/benchmark_result"
require_relative "testing/model_benchmark"
require_relative "testing/requirement_builder"
require_relative "testing/agent_spec"
require_relative "testing/auto_gen"
require_relative "testing/auto_stub"
require_relative "testing/behavior_tracer"

module Smolagents
  # Testing utilities for smolagents.
  #
  # Provides MockModel, helpers, and matchers for deterministic agent testing,
  # plus model benchmarking infrastructure for evaluating LLM compatibility.
  #
  # == Unit Testing
  #
  # For testing agents without real LLM calls:
  #
  # - {MockModel}: Deterministic model that queues responses
  # - {Helpers}: Helper methods for common test patterns
  # - {Matchers}: RSpec matchers for agent assertions
  # - {SpyTool}: Tool that records calls for verification
  # - {Fixtures}: Factory methods for test data objects
  #
  # @example Basic usage
  #   model = Smolagents::Testing::MockModel.new
  #   model.queue_final_answer("42")
  #   model.call_count  #=> 0
  #
  # @example Multi-step test
  #   model = Smolagents::Testing::MockModel.new
  #   model.queue_code_action("search(query: 'Ruby 4.0')")
  #   model.queue_final_answer("Ruby 4.0 was released in 2024")
  #   model.remaining_responses  #=> 2
  #
  # @example Using helpers
  #   model = Smolagents::Testing::MockModel.new
  #   model.queue_final_answer("done")
  #   model.remaining_responses  #=> 1
  #
  # @example RSpec configuration
  #   Smolagents::Testing.respond_to?(:configure_rspec)  #=> true
  #
  # == Model Benchmarking
  #
  # For evaluating model compatibility with smolagents:
  #
  # - {ModelCapabilities}: Describes what a model can do
  # - {ModelRegistry}: Discovers and catalogs available models
  # - {ModelBenchmark}: Runs tiered tests to evaluate compatibility
  # - {BenchmarkResult}: Captures test results
  # - {BenchmarkSummary}: Reports on benchmark runs
  #
  # @example Quick model evaluation
  #   # Discover available models
  #   registry = Smolagents::Testing::ModelRegistry.from_lm_studio
  #
  #   # Run benchmarks
  #   benchmark = Smolagents::Testing::ModelBenchmark.new
  #   summary = benchmark.run("gpt-oss-20b")
  #   puts summary.report
  #
  # @example Benchmark all models
  #   registry = Smolagents::Testing::ModelRegistry.from_lm_studio
  #   benchmark = Smolagents::Testing::ModelBenchmark.new
  #
  #   summaries = benchmark.run_all_models(registry)
  #   summaries.each { |id, s| puts s.report }
  #
  # @see MockModel Deterministic model for testing
  # @see Helpers Helper methods for test setup
  # @see Matchers RSpec matchers for agents
  # @see ModelBenchmark Model compatibility testing
  module Testing
    class << self
      # Configure RSpec with testing helpers and matchers.
      #
      # Call this in your RSpec configuration to include helpers and matchers
      # in all test examples.
      #
      # @param config [RSpec::Core::Configuration] RSpec configuration object
      # @return [void]
      #
      # @example
      #   RSpec.configure do |config|
      #     Smolagents::Testing.configure_rspec(config)
      #   end
      def configure_rspec(config)
        config.include Helpers
        config.include Matchers
      end

      # Quick benchmark of a single model.
      #
      # @param model_id [String] Model ID to test
      # @param base_url [String] LM Studio base URL
      # @param levels [Range] Test levels to run
      # @return [BenchmarkSummary]
      def benchmark(model_id, base_url: Config::DEFAULT_LOCAL_API_URL, levels: 1..5)
        bench = ModelBenchmark.new(base_url:)
        bench.run(model_id, levels:)
      end

      # Discover models from LM Studio.
      #
      # @param base_url [String] LM Studio base URL
      # @return [ModelRegistry]
      def discover_models(base_url: Config::DEFAULT_LOCAL_BASE_URL)
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
      # @return [String] Formatted comparison table
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
        [id.ljust(w[:model]), (caps&.size_str || "?").rjust(w[:params])]
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
