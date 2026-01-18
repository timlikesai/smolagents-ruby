module Smolagents
  module Builders
    # Test case building methods for TestBuilder.
    #
    # Provides methods to build TestCase objects from configuration
    # and populate builders from existing test cases.
    module TestBuilderTestCaseBuilding
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
    end
  end
end
