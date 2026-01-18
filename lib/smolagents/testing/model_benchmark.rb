require_relative "model_benchmark/test_definitions"
require_relative "model_benchmark/tools"
require_relative "model_benchmark/runner"
require_relative "model_benchmark/aggregator"

module Smolagents
  module Testing
    # Tiered benchmark suite for evaluating model compatibility.
    # Tests 6 capability levels: basic, code, tool, multi-step, reasoning, vision.
    #
    # @example
    #   summary = ModelBenchmark.new.run("gpt-oss-20b")
    class ModelBenchmark
      include TestDefinitions
      include BenchmarkTools
      include Runner
      include Aggregator

      attr_reader :base_url, :logger, :registry

      # Initialize a new benchmark suite.
      #
      # @param base_url [String] API base URL for model requests
      # @param logger [Logger, nil] Logger instance for output
      # @param registry [ModelRegistry, nil] Pre-loaded model registry
      def initialize(base_url: Config::DEFAULT_LOCAL_API_URL, logger: nil, registry: nil)
        @base_url = base_url
        @logger = logger || default_logger
        @registry = registry || load_registry
      end

      # Run full benchmark on a single model.
      #
      # @param model_id [String] Model ID to test
      # @param levels [Range] Test levels to run (default 1..5)
      # @param timeout [Integer] Timeout per test in seconds (default 60)
      # @param runs [Integer] Number of runs per test for reliability (default 1)
      # @param pass_threshold [Float] Fraction of runs that must pass (default 0.5)
      # @return [BenchmarkSummary] Aggregated results for the model
      def run(model_id, levels: 1..5, timeout: 60, runs: 1, pass_threshold: 0.5)
        results = run_levels(model_id, levels, timeout:, runs:, pass_threshold:)
        BenchmarkSummary.from_results(model_id, results, capabilities: @registry[model_id])
      end

      # Run benchmark on all models in a registry.
      #
      # @param registry [ModelRegistry] Registry of models to test
      # @param levels [Range] Test levels to run (default 1..5)
      # @return [Hash{String => BenchmarkSummary}] Model ID to summary mapping
      def run_all_models(registry = @registry, levels: 1..5)
        summaries = {}
        registry.each do |caps|
          max_level = caps.vision? ? 6 : 5
          actual_levels = levels.to_a & (1..max_level).to_a
          @logger.info("Benchmarking #{caps.model_id}...")
          summaries[caps.model_id] = run(caps.model_id, levels: actual_levels)
        end
        summaries
      end

      private

      def run_levels(model_id, levels, timeout:, runs:, pass_threshold:)
        results = []
        levels.each do |level|
          continue = run_level_tests(model_id, level, results, timeout:, runs:, pass_threshold:)
          break unless continue
        end
        results
      end

      def run_level_tests(model_id, level, results, timeout:, runs:, pass_threshold:)
        tests_for_level(level).all? do |test|
          result = run_test_with_retries(model_id, test, timeout:, runs:, pass_threshold:)
          results << result
          log_result(result)
          result.passed?
        end
      end

      def log_result(result)
        status = result.passed? ? "PASS" : "FAIL"
        @logger.info("[#{status}] #{result.test_name} (#{result.duration.round(2)}s)")
      end

      def default_logger
        require "logger"
        Logger.new($stdout, level: Logger::INFO, progname: "benchmark")
      end

      def load_registry
        base = @base_url.sub(%r{/v1/?$}, "")
        ModelRegistry.from_lm_studio(base)
      rescue StandardError
        ModelRegistry.new({})
      end
    end
  end
end
