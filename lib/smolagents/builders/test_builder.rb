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
      extend Support::SetterFactory
      include Support::Introspection

      DEFAULT_CONFIG = {
        task: nil, validator: nil, tools: [], max_steps: 5, timeout: 60,
        run_count: 1, pass_threshold: 1.0, metrics: [], name: nil, capability: :text
      }.freeze

      # Method registry for introspection (similar to Base::Metadata)
      @registered_methods = {
        task: { description: "Set the test task/prompt", required: true, aliases: [] },
        expects: { description: "Set validation block for result", required: true, aliases: [] },
        max_steps: { description: "Set maximum agent steps (default: 5)", required: false, aliases: [] },
        timeout: { description: "Set execution timeout in seconds (default: 60)", required: false, aliases: [] },
        run_n_times: { description: "Set number of test runs for reliability testing", required: false, aliases: [] },
        pass_threshold: { description: "Set required pass rate (0.0-1.0, default: 1.0)", required: false, aliases: [] },
        name: { description: "Set test name identifier", required: false, aliases: [] },
        capability: { description: "Set tested capability (:text, :code, :tool_use)", required: false, aliases: [] },
        tools: { description: "Set tools available to the agent", required: false, aliases: [] },
        metrics: { description: "Set metrics to collect during test", required: false, aliases: [] }
      }.freeze

      class << self
        attr_reader :registered_methods

        def required_methods = @registered_methods.select { |_, m| m[:required] }.keys
      end

      # Simple setters generated via SetterFactory
      define_setters({
                       task: { key: :task },
                       max_steps: { key: :max_steps },
                       timeout: { key: :timeout },
                       run_n_times: { key: :run_count },
                       pass_threshold: { key: :pass_threshold },
                       name: { key: :name },
                       capability: { key: :capability },
                       tools: { key: :tools, transform: :flatten },
                       metrics: { key: :metrics, transform: :flatten }
                     })

      # Creates a new TestBuilder with default configuration.
      def initialize
        @config = DEFAULT_CONFIG.dup
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

      private

      # Map method names to configuration keys for introspection.
      def field_to_config_key(name)
        { expects: :validator }[name] || name
      end
    end
  end
end
