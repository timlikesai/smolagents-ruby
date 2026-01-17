module Smolagents
  module Testing
    # Builder for defining agent capability requirements.
    #
    # Provides a fluent DSL for specifying what capabilities an agent requires,
    # including standard capability dimensions and custom tests. Can be used to
    # build test suites or rank models by how well they meet requirements.
    #
    # @example Define requirements for a tool-using agent
    #   builder = RequirementBuilder.new("tool_agent")
    #     .requires(:tool_use, max: 5)
    #     .requires(:reasoning)
    #     .reliability(runs: 3, threshold: 0.8)
    #
    #   suite = builder.build
    #
    # @example Add custom tests
    #   builder = RequirementBuilder.new("custom_agent")
    #     .requires(:basic_reasoning)
    #     .test("custom_test") do |t|
    #       t.capability(:custom)
    #       t.task("Do something custom")
    #       t.validator(->(r) { r.include?("expected") })
    #     end
    #
    # @example Rank models by requirements
    #   builder = RequirementBuilder.new("my_agent")
    #     .requires(:tool_use)
    #
    #   scores = builder.rank_models(model_candidates) do |test_case, model|
    #     # Run test_case on model, return TestResult
    #   end
    #
    # @see TestSuite
    # @see ModelScore
    class RequirementBuilder
      def initialize(name)
        @name = name
        @requirements = []
        @custom_tests = []
        @reliability_config = { runs: 1, threshold: 1.0 }
      end

      # Require a capability dimension (all tests for that capability).
      #
      # @param capability [Symbol] The capability to require (e.g., :tool_use, :reasoning)
      # @param constraints [Hash] Optional constraints to apply to tests
      # @option constraints [Integer] :max Maximum steps for tests
      # @return [self] For method chaining
      def requires(capability, **constraints)
        tests = Capabilities.for_capability(capability)
        tests = tests.map { |tc| tc.with(max_steps: constraints[:max]) } if constraints[:max]
        @requirements.concat(tests)
        self
      end

      # Require a specific test by name.
      #
      # @param name [String, Symbol] The test name
      # @param constraints [Hash] Optional constraints to apply
      # @return [self] For method chaining
      def requires_test(name, **constraints)
        test_case = Capabilities.get(name)
        test_case = test_case.with(**constraints) if constraints.any?
        @requirements << test_case
        self
      end

      # Add a custom test.
      #
      # @param name [String, Symbol] The test name
      # @yield [TestCaseBuilder] Block to configure the test
      # @return [self] For method chaining
      def test(name, &block)
        builder = TestCaseBuilder.new(name)
        block&.call(builder)
        @custom_tests << builder.build
        self
      end

      # Set reliability requirements.
      #
      # @param runs [Integer] Number of times to run each test
      # @param threshold [Float] Fraction of runs that must pass (0.0-1.0)
      # @return [self] For method chaining
      def reliability(runs:, threshold:)
        @reliability_config = { runs:, threshold: }
        self
      end

      # Get all test cases (requirements + custom).
      #
      # @return [Array<TestCase>] All test cases
      def all_test_cases = @requirements + @custom_tests

      # Build a test suite from the requirements.
      #
      # @return [TestSuite] The configured test suite
      def build
        TestSuite.new(
          name: @name,
          test_cases: all_test_cases,
          reliability: @reliability_config
        )
      end

      # Rank models by how well they meet requirements.
      #
      # @param candidates [Array] Models to evaluate
      # @yield [TestCase, Object] Block that runs a test on a model, returns TestResult
      # @return [Array<ModelScore>] Sorted scores (best first)
      def rank_models(candidates)
        scores = candidates.map do |model_info|
          results = all_test_cases.map { |tc| yield(tc, model_info) }
          ModelScore.new(
            model_id: model_info.respond_to?(:model_id) ? model_info.model_id : model_info.to_s,
            capabilities_passed: passed_capabilities(results),
            pass_rate: results.count(&:passed) / results.size.to_f,
            results:
          )
        end
        scores.sort_by { |score| [-score.pass_rate, score.model_id] }
      end

      private

      def passed_capabilities(results)
        results.select(&:passed).map { |r| r.test_case.capability }.uniq
      end
    end

    # Simple test suite container.
    #
    # @example
    #   suite = TestSuite.new(
    #     name: "my_suite",
    #     test_cases: [test1, test2],
    #     reliability: { runs: 3, threshold: 0.8 }
    #   )
    TestSuite = Data.define(:name, :test_cases, :reliability)

    # Model ranking result.
    #
    # @example
    #   score = ModelScore.new(
    #     model_id: "gpt-4",
    #     capabilities_passed: [:tool_use, :reasoning],
    #     pass_rate: 0.9,
    #     results: [...]
    #   )
    #   score.passed?(:tool_use)  #=> true
    ModelScore = Data.define(:model_id, :capabilities_passed, :pass_rate, :results) do
      # Check if a specific capability was passed.
      #
      # @param capability [Symbol] The capability to check
      # @return [Boolean] True if the capability was passed
      def passed?(capability) = capabilities_passed.include?(capability)
    end

    # Builder for creating custom test cases.
    #
    # @example
    #   builder = TestCaseBuilder.new("my_test")
    #   builder.capability(:reasoning)
    #   builder.task("What is 2 + 2?")
    #   builder.validator(->(r) { r.include?("4") })
    #   test_case = builder.build
    class TestCaseBuilder
      def initialize(name)
        @name = name
        @capability = :custom
        @task = ""
        @tools = []
        @validator = nil
        @max_steps = 5
        @timeout = 60
      end

      # Set the capability being tested.
      #
      # @param cap [Symbol] The capability name
      # @return [self] For method chaining
      def capability(cap)
        @capability = cap
        self
      end

      # Set the task prompt.
      #
      # @param prompt [String] The task to give the agent
      # @return [self] For method chaining
      def task(prompt)
        @task = prompt
        self
      end

      # Set required tools.
      #
      # @param tool_names [Array<Symbol>] Tool names
      # @return [self] For method chaining
      def tools(*tool_names)
        @tools = tool_names.flatten
        self
      end

      # Set the validator.
      #
      # @param proc [Proc] Validation proc
      # @return [self] For method chaining
      def validator(proc)
        @validator = proc
        self
      end

      # Set maximum steps.
      #
      # @param steps [Integer] Maximum steps
      # @return [self] For method chaining
      def max_steps(steps)
        @max_steps = steps
        self
      end

      # Set timeout.
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [self] For method chaining
      def timeout(seconds)
        @timeout = seconds
        self
      end

      # Build the test case.
      #
      # @return [TestCase] The configured test case
      def build
        TestCase.new(
          name: @name,
          capability: @capability,
          task: @task,
          tools: @tools,
          validator: @validator,
          max_steps: @max_steps,
          timeout: @timeout
        )
      end
    end
  end
end
