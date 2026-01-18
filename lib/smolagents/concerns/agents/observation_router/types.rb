module Smolagents
  module Concerns
    module ObservationRouter
      # Valid routing decisions.
      VALID_DECISIONS = %i[summary_only full_output needs_retry irrelevant].freeze

      # Routing decision with summary and guidance.
      #
      # @!attribute [r] decision
      #   @return [Symbol] One of :summary_only, :full_output, :needs_retry, :irrelevant
      # @!attribute [r] summary
      #   @return [String] Concise summary of what was found
      # @!attribute [r] relevance
      #   @return [Float] 0.0-1.0 how relevant to the task
      # @!attribute [r] next_action
      #   @return [String] Suggested next step for the agent
      # @!attribute [r] full_output
      #   @return [String, nil] Original output (included based on decision)
      RoutingResult = Data.define(:decision, :summary, :relevance, :next_action, :full_output) do
        def summary_only? = decision == :summary_only
        def needs_full_output? = decision == :full_output
        def needs_retry? = decision == :needs_retry
        def irrelevant? = decision == :irrelevant

        # What the agent sees in observations
        def to_observation
          parts = ["[#{decision.to_s.upcase}] #{summary}"]
          parts << "Suggested: #{next_action}" if next_action
          parts << "\nFull output:\n#{full_output}" if needs_full_output? && full_output
          parts.join("\n")
        end

        # Creates a pass-through result (no routing)
        def self.passthrough(output)
          new(
            decision: :full_output,
            summary: "Tool returned #{output.to_s.length} characters",
            relevance: 1.0,
            next_action: nil,
            full_output: output
          )
        end
      end
    end
  end
end
