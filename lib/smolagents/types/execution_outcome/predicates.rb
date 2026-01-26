module Smolagents
  module Types
    module OutcomeComponents
      # Shared predicate methods for all execution outcome types.
      #
      # Uses TypeSupport::StatePredicates to generate state predicates.
      # Include this module in Data.define blocks to get consistent state predicates.
      # Requires the including type to have a `state` field.
      #
      # @example Including in a Data.define
      #   MyOutcome = Data.define(:state, :value) do
      #     include OutcomeComponents::Predicates
      #   end
      module Predicates
        def self.included(base)
          base.include(TypeSupport::StatePredicates)
          base.state_predicates success: :success,
                                final_answer: :final_answer,
                                error: :error,
                                max_steps: :max_steps_reached,
                                timeout: :timeout
        end

        # Checks if execution completed (success or final answer).
        #
        # @return [Boolean] True if completed successfully
        def completed? = success? || final_answer?

        # Checks if execution failed (error, max steps, or timeout).
        #
        # @return [Boolean] True if failed
        def failed? = error? || max_steps? || timeout?
      end
    end
  end
end
