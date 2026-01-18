module Smolagents
  module Testing
    # Container module for RequirementBuilder concerns.
    module RequirementBuilderConcerns
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
  end
end
