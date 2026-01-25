module Smolagents
  module Types
    # Represents a validation rejection with reason and guidance.
    #
    # Used by CompletionValidation to communicate why a completion attempt
    # was rejected and what the agent should do to address it.
    #
    # @example Creating a rejection
    #   rejection = ValidationRejection.new(
    #     reason: "Plan has incomplete steps",
    #     guidance: "Complete remaining plan steps before calling final_answer"
    #   )
    #
    # @example Pattern matching
    #   case validation_result
    #   in ValidationRejection[reason:, guidance:]
    #     inject_feedback("Rejected: #{reason}\n#{guidance}")
    #   end
    #
    # @see Concerns::CompletionValidation The validation concern
    ValidationRejection = Data.define(:reason, :guidance) do
      include TypeSupport::Deconstructable

      # Whether this rejection has actionable guidance.
      # @return [Boolean]
      def actionable? = !guidance.nil? && !guidance.empty?

      # Formats the rejection for display to the agent.
      # @return [String]
      def to_feedback
        parts = ["[COMPLETION REJECTED] #{reason}"]
        parts << guidance if actionable?
        parts << "Continue working on the task. Do not call final_answer until ready."
        parts.join("\n\n")
      end

      class << self
        # Creates a rejection for incomplete plan.
        #
        # @param guidance [String] Specific guidance for completing the plan
        # @return [ValidationRejection]
        def incomplete_plan(guidance: nil)
          new(
            reason: "Plan has incomplete steps",
            guidance: guidance || "Complete remaining plan steps before calling final_answer, " \
                                  "or update the plan if steps are no longer needed."
          )
        end

        # Creates a rejection for goal misalignment.
        #
        # @param task [String] The original task (truncated for display)
        # @return [ValidationRejection]
        def goal_misalignment(task:)
          new(
            reason: "Answer may not address the original task",
            guidance: "Ensure your answer directly addresses: #{task.to_s.slice(0, 100)}"
          )
        end

        # Creates a custom rejection with explicit reason and guidance.
        #
        # @param reason [String] Why the completion was rejected
        # @param guidance [String] What the agent should do
        # @return [ValidationRejection]
        def custom(reason:, guidance:)
          new(reason:, guidance:)
        end
      end
    end
  end
end
