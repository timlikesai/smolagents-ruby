module Smolagents
  module Types
    # Valid aggregation strategies for Mixture-of-Agents.
    AGGREGATION_STRATEGIES = %i[voting synthesis rank_fusion].freeze

    # Result of aggregating multiple proposals in the MoA pattern.
    # @see Proposal, MoAConfig
    AggregationResult = Data.define(
      :final_answer,         # The aggregated output value
      :selected_proposal,    # Name of winning proposal (for voting) or nil
      :strategy,             # Symbol: :voting, :synthesis, or :rank_fusion
      :all_proposals,        # Array<Proposal> of all inputs
      :synthesis_reasoning,  # String explanation of synthesis (for synthesis strategy)
      :duration_ms           # Aggregation execution time
    ) do
      include TypeSupport::Deconstructable

      class << self
        # Creates a synthesis result combining proposals.
        def from_synthesis(all_proposals, final_answer, reasoning = nil, duration_ms: nil)
          new(final_answer:, selected_proposal: nil, strategy: :synthesis,
              all_proposals:, synthesis_reasoning: reasoning, duration_ms:)
        end

        # Creates a voting result selecting highest-confidence proposal.
        def from_voting(all_proposals, duration_ms: nil)
          winner = all_proposals.max_by { |p| p.confidence || 0.0 }
          new(final_answer: winner&.result, selected_proposal: winner&.proposer_name,
              strategy: :voting, all_proposals:, synthesis_reasoning: nil, duration_ms:)
        end
      end

      # Average confidence across all proposals.
      def confidence_estimate
        confidences = all_proposals.filter_map(&:confidence)
        confidences.empty? ? nil : confidences.sum / confidences.size.to_f
      end

      def voting? = strategy == :voting
      def synthesis? = strategy == :synthesis
      def rank_fusion? = strategy == :rank_fusion
      def proposal_count = all_proposals.size

      # Checks if all proposals agree (same result).
      def unanimous?
        return true if all_proposals.size <= 1

        all_proposals.all? { |p| p.result == all_proposals.first.result }
      end

      def proposals_by_confidence = all_proposals.sort_by { |p| -(p.confidence || 0.0) }

      def to_h
        { final_answer:, selected_proposal:, strategy:, all_proposals: all_proposals.map(&:to_h),
          synthesis_reasoning:, duration_ms:, confidence_estimate: }
      end
    end
  end
end
