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
    # @example Reliability testing
    #   Smolagents::Builders::TestBuilder.create
    #     .task("Solve 2 + 2")
    #     .expects { |r| r == "4" }
    #     .run_n_times(5)
    #     .pass_threshold(0.8)
    #     .run(model)
    #
    # @example Using MockModel for unit tests
    #   Smolagents::Builders::TestBuilder.create
    #     .task("Do something")
    #     .expects { |r| r.include?("done") }
    #     .with_mock do |mock|
    #       mock.queue_final_answer("done")
    #     end
    #
    # @see Testing::TestCase
    # @see Testing::TestRunner
    # @see Testing::TestRun
    TestBuilder = Data.define(:configuration) do
      include Base

      def self.default_configuration
        { task: nil, validator: nil, tools: [], max_steps: 5, timeout: 60,
          run_count: 1, pass_threshold: 1.0, metrics: [], name: nil, capability: :text }
      end

      # Create a new builder with default configuration.
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

      # Set the test task prompt.
      # @param prompt [String] The task prompt
      # @return [TestBuilder] New builder with updated configuration
      def task(prompt) = with_config(task: prompt)

      # Set the maximum number of agent steps.
      # @param steps [Integer] Maximum steps
      # @return [TestBuilder] New builder with updated configuration
      def max_steps(steps) = with_config(max_steps: steps)

      # Set the execution timeout in seconds.
      # @param seconds [Integer] Timeout in seconds
      # @return [TestBuilder] New builder with updated configuration
      def timeout(seconds) = with_config(timeout: seconds)

      # Set the number of test runs for reliability testing.
      # @param count [Integer] Number of runs
      # @return [TestBuilder] New builder with updated configuration
      def run_n_times(count) = with_config(run_count: count)

      # Set the required pass rate threshold.
      # @param threshold [Float] Pass threshold (0.0-1.0)
      # @return [TestBuilder] New builder with updated configuration
      def pass_threshold(threshold) = with_config(pass_threshold: threshold)

      # Set the test name identifier.
      # @param test_name [String] Test name
      # @return [TestBuilder] New builder with updated configuration
      def name(test_name) = with_config(name: test_name)

      # Set the tested capability.
      # @param cap [Symbol] Capability (:text, :code, :tool_use)
      # @return [TestBuilder] New builder with updated configuration
      def capability(cap) = with_config(capability: cap)

      # Set tools available to the agent.
      # @param tool_list [Array] Tools to make available
      # @return [TestBuilder] New builder with updated configuration
      def tools(*tool_list) = with_config(tools: tool_list.flatten)

      # Set metrics to collect during test.
      # @param metric_list [Array] Metrics to collect
      # @return [TestBuilder] New builder with updated configuration
      def metrics(*metric_list) = with_config(metrics: metric_list.flatten)

      # Sets a validation block for the test result.
      #
      # @yield [result] Block that receives the agent's output
      # @yieldparam result [String] The agent's final answer
      # @yieldreturn [Boolean] Whether the result passes validation
      # @return [TestBuilder] New builder with updated configuration
      def expects(&block) = with_config(validator: block)

      # Sets a validator object/proc for the test result.
      #
      # @param validator [#call] Any callable that validates the result
      # @return [TestBuilder] New builder with updated configuration
      def expects_validator(validator) = with_config(validator:)

      # Builds a TestCase from the current configuration.
      #
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
      #
      # @param model [Models::Model] The model to test
      # @return [Testing::TestRun] Aggregated results from all runs
      def run(model)
        test_case = build_test_case
        runner = Testing::TestRunner.new(test_case, model)
        runner.run(times: configuration[:run_count], threshold: configuration[:pass_threshold])
      end

      # Runs the test with a MockModel configured via block.
      #
      # @yield [mock] Block to configure the mock model
      # @yieldparam mock [Testing::MockModel] The mock model to configure
      # @return [Testing::TestRun] Test results
      def with_mock
        mock = Testing::MockModel.new
        yield(mock)
        run(mock)
      end

      # Populate the builder from an existing test case.
      #
      # Copies all settings from a test case into the builder for reuse or modification.
      #
      # @param test_case [Testing::TestCase] Source test case
      # @return [TestBuilder] New builder with test case configuration
      def from(test_case)
        with_config(
          name: test_case.name,
          capability: test_case.capability,
          task: test_case.task,
          tools: test_case.tools,
          validator: test_case.validator,
          max_steps: test_case.max_steps,
          timeout: test_case.timeout
        )
      end

      # Returns a copy of the current configuration.
      #
      # @return [Hash] Configuration hash
      def config = configuration.dup

      private

      # Create a new builder with merged configuration.
      # @param kwargs [Hash] Configuration updates
      # @return [TestBuilder] New builder with merged configuration
      def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))

      # Map method names to configuration keys for introspection.
      # @param name [Symbol] Field name
      # @return [Symbol] Configuration key
      def field_to_config_key(name)
        { expects: :validator }[name] || name
      end
    end
  end
end
