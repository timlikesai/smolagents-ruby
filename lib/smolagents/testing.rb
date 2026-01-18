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
require_relative "testing/comparison_table"

module Smolagents
  # Testing utilities for smolagents.
  #
  # Provides MockModel, helpers, and matchers for deterministic agent testing,
  # plus model benchmarking infrastructure for evaluating LLM compatibility.
  #
  # @see MockModel Deterministic model for testing
  # @see Helpers Helper methods for test setup
  # @see Matchers RSpec matchers for agents
  # @see ModelBenchmark Model compatibility testing
  module Testing
    class << self
      # Configure RSpec with testing helpers and matchers.
      #
      # @param config [RSpec::Core::Configuration] RSpec configuration object
      # @return [void]
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

      # Print a comparison table of all models.
      #
      # @param summaries [Hash{String => BenchmarkSummary}]
      # @return [String] Formatted comparison table
      def comparison_table(summaries)
        ComparisonTable.format(summaries)
      end
    end
  end
end
