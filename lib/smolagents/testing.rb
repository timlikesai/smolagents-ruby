# Ensure main library is loaded first for all dependencies
require "smolagents" unless defined?(Smolagents::Models::Model)

require_relative "testing/test_mode"
require_relative "testing/test_logger"
require_relative "testing/call_log"
require_relative "testing/call_log_support"
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
require_relative "testing/scenarios"
require_relative "testing/behavior_tracer"
require_relative "testing/comparison_table"
require_relative "testing/tool_execution_tests"
require_relative "testing/shared_examples"

module Smolagents
  # Testing utilities for smolagents.
  #
  # Provides MockModel, helpers, and matchers for deterministic agent testing,
  # plus model benchmarking infrastructure for evaluating LLM compatibility.
  #
  # == Test Mode API
  #
  # Enable test mode globally for deterministic testing:
  #
  #   Smolagents.test_mode!
  #   agent = Smolagents.agent.model { mock }.build
  #   agent.run("task")
  #
  # Or scope it to a block:
  #
  #   Smolagents.test_mode do
  #     agent.run("task")
  #   end
  #
  # @see MockModel Deterministic model for testing
  # @see Helpers Helper methods for test setup
  # @see Matchers RSpec matchers for agents
  # @see CallLog Recording agent execution for assertions
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

      # Creates a new CallLog for recording agent execution.
      #
      # @return [CallLog]
      def call_log = CallLog.new

      # Returns a test scenario for common patterns.
      #
      # @param name [Symbol] Scenario name
      # @param args [Array] Positional arguments for the scenario
      # @param options [Hash] Keyword arguments for the scenario
      # @return [MockModel, Array] Scenario result
      #
      # @example
      #   model, answer = Smolagents::Testing.scenario(:simple_answer)
      #   model = Smolagents::Testing.scenario(:multi_step, steps: 3)
      #
      # @see Scenarios For available scenarios
      def scenario(name, *args, **)
        raise ArgumentError, "Unknown scenario: #{name}" unless Scenarios.respond_to?(name)

        if args.empty?
          Scenarios.public_send(name, **)
        else
          Scenarios.public_send(name, *args, **)
        end
      end

      # ============================================================
      # Test Mode API (delegated to TestMode)
      # ============================================================

      # Enables test mode globally.
      # @see TestMode#enable!
      def test_mode! = TestMode.enable!

      # Checks if test mode is enabled.
      # @see TestMode#test_mode?
      def test_mode? = TestMode.test_mode?

      # Executes a block in test mode.
      # @see TestMode#scope
      def test_mode(&) = TestMode.scope(&)

      # Returns test mode configuration.
      # @see TestMode#configuration
      def configuration = TestMode.configuration

      # Configures test mode settings.
      # @see TestMode#configure
      def configure(&) = TestMode.configure(&)

      # Resets test mode to defaults.
      # @see TestMode#reset!
      def reset! = TestMode.reset!
    end
  end

  # ============================================================
  # Top-level Test Mode DSL
  # ============================================================

  class << self
    # Enables test mode for deterministic agent testing.
    #
    # When test mode is enabled:
    # - Network requests are blocked by default
    # - Verbose events are emitted for debugging
    # - Call logs are automatically recorded
    #
    # @return [Testing::TestMode]
    #
    # @example Enable test mode
    #   Smolagents.test_mode!
    #   # Now all agents run in test mode
    #
    # @see Testing::TestMode For configuration options
    def test_mode! = Testing.test_mode!

    # Checks if test mode is currently enabled.
    #
    # @return [Boolean]
    def test_mode? = Testing.test_mode?

    # Executes a block in test mode.
    #
    # Test mode is automatically disabled after the block completes,
    # even if an exception is raised. Use this for isolated tests.
    #
    # @yield Block to execute in test mode
    # @return [Object] Result of the block
    #
    # @example Scoped test mode
    #   Smolagents.test_mode { :test_mode_active }
    #   # Test mode is now disabled
    def test_mode(&) = Testing.test_mode(&)
  end
end
