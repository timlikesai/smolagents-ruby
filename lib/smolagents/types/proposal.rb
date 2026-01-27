module Smolagents
  module Types
    # Single proposer's solution in the Mixture-of-Agents pattern.
    # @see AggregationResult, MoAConfig
    Proposal = Data.define(
      :proposer_name,   # String identifier for the proposer agent
      :task,            # Original task string
      :result,          # Output value from the proposer
      :reasoning,       # Explanation/thought process
      :confidence,      # Float 0.0-1.0 confidence score
      :duration_ms,     # Execution time in milliseconds
      :metadata         # Hash for extra context
    ) do
      include TypeSupport::Deconstructable

      class << self
        # Creates a Proposal from a RunResult.
        def from_run_result(proposer_name, task, run_result)
          new(
            proposer_name:,
            task:,
            result: run_result.output,
            reasoning: extract_reasoning(run_result),
            confidence: extract_confidence(run_result),
            duration_ms: run_result.duration && (run_result.duration * 1000).to_i,
            metadata: {}
          )
        end

        private

        def extract_reasoning(run_result) = run_result.action_steps.filter_map(&:observations).join("\n\n")

        def extract_confidence(run_result)
          return nil unless run_result.success?

          # Default confidence based on outcome state
          run_result.error? ? 0.3 : 0.7
        end
      end

      # Brief summary with name, truncated result, and confidence.
      def summary
        result_preview = result.to_s[0..50]
        result_preview += "..." if result.to_s.length > 50
        conf = confidence ? " (#{(confidence * 100).round}%)" : ""
        "#{proposer_name}: #{result_preview}#{conf}"
      end

      def high_confidence? = (confidence || 0.0) >= 0.8
      def confident?(threshold: 0.7) = (confidence || 0.0) >= threshold
      def low_confidence?(threshold: 0.4) = (confidence || 0.0) < threshold
      def to_h = { proposer_name:, task:, result:, reasoning:, confidence:, duration_ms:, metadata: }
    end
  end
end
