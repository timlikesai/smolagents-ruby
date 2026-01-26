require_relative "requirement_builder/types"
require_relative "requirement_builder/test_case_builder"
require_relative "requirement_builder/model_ranking"

module Smolagents
  module Testing
    # Builder for defining agent capability requirements.
    #
    # Provides a fluent DSL for specifying what capabilities an agent requires.
    # Use to build test suites or rank models by how well they meet requirements.
    #
    # @example
    #   RequirementBuilder.new("my_agent")
    #     .requires(:tool_use, max: 5)
    #     .test("custom") { |t| t.task("Do X"); t.validator(->(r) { r.ok? }) }
    #     .reliability(runs: 3, threshold: 0.8)
    #     .build
    class RequirementBuilder
      include RequirementBuilderConcerns::ModelRanking

      DEFAULT_RELIABILITY = { runs: 1, threshold: 1.0 }.freeze

      def initialize(name)
        @name = name
        @requirements = []
        @custom_tests = []
        @reliability_config = DEFAULT_RELIABILITY.dup
      end

      # Require a capability dimension (all tests for that capability).
      #
      # @param capability [Symbol] The capability to require
      # @param constraints [Hash] Optional constraints (e.g., max: 10 for max_steps)
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
    end
  end
end
