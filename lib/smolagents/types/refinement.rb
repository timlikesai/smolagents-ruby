module Smolagents
  module Types
    # Configuration for self-refine behavior.
    #
    # @!attribute [r] max_iterations
    #   @return [Integer] Maximum refinement attempts (default: 3)
    # @!attribute [r] feedback_source
    #   @return [Symbol] Where to get feedback (:execution, :self, :evaluation)
    # @!attribute [r] min_confidence
    #   @return [Float] Minimum confidence to accept without refinement (0.0-1.0)
    # @!attribute [r] enabled
    #   @return [Boolean] Whether refinement is enabled
    RefineConfig = Data.define(:max_iterations, :feedback_source, :min_confidence, :enabled) do
      DEFAULT_MAX_ITERATIONS = 3
      DEFAULT_FEEDBACK_SOURCE = :execution

      def self.default
        new(
          max_iterations: DEFAULT_MAX_ITERATIONS,
          feedback_source: DEFAULT_FEEDBACK_SOURCE,
          min_confidence: 0.8,
          enabled: true
        )
      end

      def self.disabled
        new(max_iterations: 0, feedback_source: :execution, min_confidence: 1.0, enabled: false)
      end
    end

    # Result of a refinement cycle.
    #
    # @!attribute [r] original
    #   @return [Object] Original response before refinement
    # @!attribute [r] refined
    #   @return [Object] Final refined response
    # @!attribute [r] iterations
    #   @return [Integer] Number of refinement iterations performed
    # @!attribute [r] feedback_history
    #   @return [Array<RefinementFeedback>] Feedback from each iteration
    # @!attribute [r] improved
    #   @return [Boolean] Whether refinement improved the result
    # @!attribute [r] confidence
    #   @return [Float] Final confidence score
    RefinementResult = Data.define(:original, :refined, :iterations, :feedback_history, :improved, :confidence) do
      def refined? = iterations.positive?
      def maxed_out?(max) = iterations >= max
      def final = improved ? refined : original

      class << self
        def no_refinement_needed(response, confidence: 1.0)
          new(original: response, refined: response, iterations: 0, feedback_history: [], improved: false, confidence:)
        end

        def after_refinement(original:, refined:, iterations:, feedback_history:, improved:, confidence:)
          new(original:, refined:, iterations:, feedback_history:, improved:, confidence:)
        end
      end
    end

    # Feedback from a single refinement iteration.
    #
    # @!attribute [r] iteration
    #   @return [Integer] Which iteration this feedback is from
    # @!attribute [r] source
    #   @return [Symbol] Feedback source (:execution, :self, :evaluation)
    # @!attribute [r] critique
    #   @return [String] The feedback/critique content
    # @!attribute [r] actionable
    #   @return [Boolean] Whether feedback is actionable
    # @!attribute [r] confidence
    #   @return [Float] Confidence in the feedback
    RefinementFeedback = Data.define(:iteration, :source, :critique, :actionable, :confidence) do
      def suggests_improvement? = actionable && confidence > 0.5
    end
  end
end
