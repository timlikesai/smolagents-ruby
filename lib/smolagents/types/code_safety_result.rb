module Smolagents
  module Types
    # Result of static code safety analysis.
    #
    # @!attribute [r] outcome [Symbol] :safe or :rejected
    # @!attribute [r] reason [String, nil] Rejection reason if unsafe
    #
    # @example Safe code
    #   result = CodeSafetyResult.safe
    #   result.safe?  #=> true
    #
    # @example Rejected code
    #   result = CodeSafetyResult.rejected("Unbounded allocation detected")
    #   result.rejected?  #=> true
    #   result.reason     #=> "Unbounded allocation detected"
    CodeSafetyResult = Data.define(:outcome, :reason) do
      def self.safe = new(outcome: :safe, reason: nil)
      def self.rejected(reason) = new(outcome: :rejected, reason:)

      def safe? = outcome == :safe
      def rejected? = outcome == :rejected
      def deconstruct_keys(_) = { outcome:, reason: }
    end
  end
end
