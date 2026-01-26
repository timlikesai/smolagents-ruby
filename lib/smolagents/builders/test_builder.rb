require_relative "test_builder/setters"

module Smolagents
  module Builders
    # Fluent builder DSL for configuring and running model tests.
    #
    # Provides a fluent, immutable interface for defining test cases, configuring
    # execution parameters, and running tests against models.
    #
    # @example Basic test definition
    #   Smolagents::Builders::TestBuilder.create
    #     .task("What is 2 + 2?")
    #     .expects { |result| result.include?("4") }
    #     .run(model)
    #
    # @example With tools and constraints
    #   Smolagents::Builders::TestBuilder.create
    #     .name("search_test")
    #     .task("Find the latest Ruby version")
    #     .tools(:search, :web)
    #     .max_steps(8)
    #     .timeout(120)
    #     .expects { |result| result.match?(/\d+\.\d+/) }
    #     .run(model)
    #
    # @see Testing::TestCase
    # @see Testing::TestRunner
    # @see Testing::TestRun
    TestBuilder = Data.define(:configuration) do
      include Base
      include TestBuilderSetters

      def self.default_configuration
        { task: nil, validator: nil, tools: [], max_steps: 5, timeout: 60,
          run_count: 1, pass_threshold: 1.0, metrics: [], name: nil, capability: :text }
      end

      # @return [TestBuilder] New builder instance
      def self.create = new(configuration: default_configuration)

      # Required methods
      register_method :task, description: "Set the test task/prompt", required: true
      register_method :expects, description: "Set validation block for result", required: true

      # Configuration methods
      register_method :max_steps, description: "Set maximum agent steps (default: 5)"
      register_method :timeout, description: "Set execution timeout in seconds (default: 60)"
      register_method :run_n_times, description: "Set number of test runs for reliability testing"
      register_method :pass_threshold, description: "Set required pass rate (0.0-1.0, default: 1.0)"
      register_method :name, description: "Set test name identifier"
      register_method :capability, description: "Set tested capability (:text, :code, :tool_use)"
      register_method :tools, description: "Set tools available to the agent"
      register_method :metrics, description: "Set metrics to collect during test"

      # Builds a TestCase from the current configuration.
      # @return [Testing::TestCase] Immutable test case
      def build_test_case
        Testing::TestCase.new(
          name: configuration[:name] || "test_#{SecureRandom.hex(4)}",
          capability: configuration[:capability],
          task: configuration[:task],
          tools: configuration[:tools],
          validator: configuration[:validator],
          max_steps: configuration[:max_steps],
          timeout: configuration[:timeout]
        )
      end

      # Runs the test against a model.
      # @param model [Models::Model] The model to test
      # @return [Testing::TestRun] Aggregated results from all runs
      def run(model)
        test_case = build_test_case
        runner = Testing::TestRunner.new(test_case, model)
        runner.run(times: configuration[:run_count], threshold: configuration[:pass_threshold])
      end

      # Runs the test with a MockModel configured via block.
      # @yield [mock] Block to configure the mock model
      # @return [Testing::TestRun] Test results
      def with_mock
        mock = Testing::MockModel.new
        yield(mock)
        run(mock)
      end

      # Populate the builder from an existing test case.
      # @param test_case [Testing::TestCase] Source test case
      # @return [TestBuilder] New builder with test case configuration
      def from(test_case)
        check_frozen!
        with_config(
          name: test_case.name, capability: test_case.capability, task: test_case.task,
          tools: test_case.tools, validator: test_case.validator,
          max_steps: test_case.max_steps, timeout: test_case.timeout
        )
      end

      # @return [Hash] Configuration hash
      def config = configuration.dup

      private

      def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))

      def field_to_config_key(name)
        { expects: :validator }[name] || name
      end
    end
  end
end
