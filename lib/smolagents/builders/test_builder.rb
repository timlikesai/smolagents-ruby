module Smolagents
  module Builders
    # Fluent builder DSL for configuring and running model tests.
    #
    # Provides a fluent interface for defining test cases, configuring execution
    # parameters, and running tests against models. Designed for composable,
    # readable test definitions.
    #
    # @example Basic test definition
    #   Smolagents::Builders::TestBuilder.new
    #     .task("What is 2 + 2?")
    #     .expects { |result| result.include?("4") }
    #     .run(model)
    #
    # @example With tools and constraints
    #   Smolagents::Builders::TestBuilder.new
    #     .name("search_test")
    #     .task("Find the latest Ruby version")
    #     .tools(:search, :web)
    #     .max_steps(8)
    #     .timeout(120)
    #     .expects { |result| result.match?(/\d+\.\d+/) }
    #     .run(model)
    #
    # @example Reliability testing
    #   Smolagents::Builders::TestBuilder.new
    #     .task("Solve 2 + 2")
    #     .expects { |r| r == "4" }
    #     .run_n_times(5)
    #     .pass_threshold(0.8)
    #     .run(model)
    #
    # @example Using MockModel for unit tests
    #   Smolagents::Builders::TestBuilder.new
    #     .task("Do something")
    #     .expects { |r| r.include?("done") }
    #     .with_mock do |mock|
    #       mock.queue_final_answer("done")
    #     end
    #
    # @see Testing::TestCase
    # @see Testing::TestRunner
    # @see Testing::TestRun
    class TestBuilder
      DEFAULT_CONFIG = {
        task: nil, validator: nil, tools: [], max_steps: 5, timeout: 60,
        run_count: 1, pass_threshold: 1.0, metrics: [], name: nil, capability: :text
      }.freeze

      # Creates a new TestBuilder with default configuration.
      def initialize
        @config = DEFAULT_CONFIG.dup
      end

      # Sets the task prompt for the test.
      #
      # @param prompt [String] The task to give the agent
      # @return [self] Builder for chaining
      def task(prompt)
        @config[:task] = prompt
        self
      end

      # Sets a validation block for the test result.
      #
      # @yield [result] Block that receives the agent's output
      # @yieldparam result [String] The agent's final answer
      # @yieldreturn [Boolean] Whether the result passes validation
      # @return [self] Builder for chaining
      def expects(&block)
        @config[:validator] = block
        self
      end

      # Sets a validator object/proc for the test result.
      #
      # @param validator [#call] Any callable that validates the result
      # @return [self] Builder for chaining
      def expects_validator(validator)
        @config[:validator] = validator
        self
      end

      # Sets the tools required for this test.
      #
      # @param tool_names [Array<Symbol>] Tool names to make available
      # @return [self] Builder for chaining
      def tools(*tool_names)
        @config[:tools] = tool_names.flatten
        self
      end

      # Sets the maximum steps allowed for this test.
      #
      # @param count [Integer] Maximum number of agent steps
      # @return [self] Builder for chaining
      def max_steps(count)
        @config[:max_steps] = count
        self
      end

      # Sets the timeout for this test.
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [self] Builder for chaining
      def timeout(seconds)
        @config[:timeout] = seconds
        self
      end

      # Sets the number of times to run the test for reliability testing.
      #
      # @param count [Integer] Number of runs
      # @return [self] Builder for chaining
      def run_n_times(count)
        @config[:run_count] = count
        self
      end

      # Sets the pass threshold for reliability testing.
      #
      # @param rate [Float] Required pass rate (0.0 to 1.0)
      # @return [self] Builder for chaining
      def pass_threshold(rate)
        @config[:pass_threshold] = rate
        self
      end

      # Sets additional metrics to collect during the test.
      #
      # @param metric_names [Array<Symbol>] Metric names to collect
      # @return [self] Builder for chaining
      def metrics(*metric_names)
        @config[:metrics] = metric_names.flatten
        self
      end

      # Sets a name for this test case.
      #
      # @param test_name [String] Test name identifier
      # @return [self] Builder for chaining
      def name(test_name)
        @config[:name] = test_name
        self
      end

      # Sets the capability being tested.
      #
      # @param cap [Symbol] Capability identifier (e.g., :text, :tool_use, :reasoning)
      # @return [self] Builder for chaining
      def capability(cap)
        @config[:capability] = cap
        self
      end

      # Builds a TestCase from the current configuration.
      #
      # @return [Testing::TestCase] Immutable test case
      def build_test_case
        Testing::TestCase.new(
          name: @config[:name] || "test_#{SecureRandom.hex(4)}",
          capability: @config[:capability],
          task: @config[:task],
          tools: @config[:tools],
          validator: @config[:validator],
          max_steps: @config[:max_steps],
          timeout: @config[:timeout]
        )
      end

      # Runs the test against a model.
      #
      # @param model [Models::Model] The model to test
      # @return [Testing::TestRun] Aggregated results from all runs
      def run(model)
        test_case = build_test_case
        runner = Testing::TestRunner.new(test_case, model)
        runner.run(times: @config[:run_count], threshold: @config[:pass_threshold])
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

      # Populates the builder from an existing test case.
      #
      # @param test_case [Testing::TestCase] Source test case
      # @return [self] Builder for chaining
      def from(test_case)
        @config[:name] = test_case.name
        @config[:capability] = test_case.capability
        @config[:task] = test_case.task
        @config[:tools] = test_case.tools
        @config[:validator] = test_case.validator
        @config[:max_steps] = test_case.max_steps
        @config[:timeout] = test_case.timeout
        self
      end

      # Returns a frozen copy of the current configuration.
      #
      # @return [Hash] Frozen configuration hash
      def config
        @config.dup.freeze
      end
    end
  end
end
