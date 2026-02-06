module Smolagents
  module Types
    # Record of a completed step in agent execution tracking.
    #
    # Used by progress trackers to record step completions with their outcomes.
    #
    # @!attribute [r] step
    #   @return [Integer] The step number that completed
    # @!attribute [r] outcome
    #   @return [Symbol] The outcome (:success, :error, :final_answer)
    #
    # @example Creating a completed step record
    #   completed = CompletedStep.new(step: 3, outcome: :success)
    #   completed.success?  # => true
    #
    # @see Interactive::Progress::StepTracker For usage context
    CompletedStep = Data.define(:step, :outcome) do
      include TypeSupport::Deconstructable
      include TypeSupport::Serializable
      include TypeSupport::StatePredicates

      state_predicates :outcome, success: :success, final_answer: :final_answer, error: :error
    end
  end
end
