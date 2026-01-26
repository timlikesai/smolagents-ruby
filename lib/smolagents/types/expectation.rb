module Smolagents
  module Types
    # Test expectation for agent scenario validation.
    #
    # Represents what an agent should (or should not) do during a test scenario.
    #
    # @!attribute [r] description
    #   @return [String] Human-readable description of the expectation
    # @!attribute [r] tool
    #   @return [Symbol, nil] Expected tool to be used
    # @!attribute [r] keywords
    #   @return [Array<String>, nil] Keywords expected in the output
    # @!attribute [r] negated
    #   @return [Boolean] If true, this is a "should not" expectation
    #
    # @example Positive expectation with tool
    #   exp = Expectation.new(
    #     description: "search for information",
    #     tool: :web_search,
    #     keywords: nil,
    #     negated: false
    #   )
    #
    # @example Negative expectation
    #   exp = Expectation.new(
    #     description: "reveal internal state",
    #     tool: nil,
    #     keywords: nil,
    #     negated: true
    #   )
    #
    # @see Testing::Scenario For usage in test scenarios
    Expectation = Data.define(:description, :tool, :keywords, :negated) do
      include TypeSupport::Deconstructable
      include TypeSupport::Serializable
      extend TypeSupport::FactoryBuilder

      factory :positive, negated: false
      factory :negative, negated: true, tool: nil, keywords: nil

      # Whether this is a positive (should) expectation.
      # @return [Boolean]
      def positive? = !negated

      # Whether this is a negative (should not) expectation.
      # @return [Boolean]
      def negative? = negated
    end
  end
end
