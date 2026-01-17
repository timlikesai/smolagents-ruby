module Smolagents
  module Types
    # Configuration for mixed-refinement with cross-model feedback.
    #
    # Mixed refinement uses a small model for generation and a larger model
    # for critique, improving quality while keeping costs low.
    #
    # @example Configure with feedback model
    #   config = MixedRefineConfig.with_feedback_model(large_model, max_iterations: 2)
    #
    # @see Concerns::MixedRefinement The mixed refinement concern
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    MixedRefineConfig = Data.define(
      :max_iterations, :feedback_source, :min_confidence, :enabled,
      :feedback_model, :feedback_temperature, :cross_model_enabled
    ) do
      # Creates default config with same-model feedback.
      def self.default
        new(
          max_iterations: 2, feedback_source: :self, min_confidence: 0.8, enabled: true,
          feedback_model: nil, feedback_temperature: 0.3, cross_model_enabled: false
        )
      end

      # Creates config with cross-model feedback enabled.
      # @param model [Model] The model to use for critique
      # @param max_iterations [Integer] Maximum refinement iterations
      def self.with_feedback_model(model, max_iterations: 2)
        new(
          max_iterations:, feedback_source: :self, min_confidence: 0.8, enabled: true,
          feedback_model: model, feedback_temperature: 0.3, cross_model_enabled: true
        )
      end

      # Creates disabled config.
      def self.disabled
        new(
          max_iterations: 0, feedback_source: :self, min_confidence: 1.0, enabled: false,
          feedback_model: nil, feedback_temperature: 0.3, cross_model_enabled: false
        )
      end

      # Convert to base RefineConfig for compatibility.
      def to_refine_config
        Concerns::SelfRefine::RefineConfig.new(max_iterations:, feedback_source:, min_confidence:, enabled:)
      end
    end

    # Result of mixed refinement with model attribution.
    #
    # Tracks which models performed generation vs feedback, enabling
    # analysis of cross-model vs same-model refinement effectiveness.
    #
    # @example Check if cross-model was used
    #   result = attempt_mixed_refinement(step, task)
    #   puts "Cross-model: #{result.cross_model}" if result.refined?
    MixedRefinementResult = Data.define(
      :original, :refined, :iterations, :feedback_history,
      :improved, :confidence, :generation_model, :feedback_model_id, :cross_model
    ) do
      # Whether any refinement occurred.
      def refined? = iterations.positive?

      # The final output (refined if improved, original otherwise).
      def final = improved ? refined : original

      # Creates result from base RefinementResult with model attribution.
      # @param result [SelfRefine::RefinementResult] Base refinement result
      # @param generation_model [String] Model that generated the output
      # @param feedback_model_id [String] Model that provided feedback
      def self.from_refinement_result(result, generation_model:, feedback_model_id:)
        new(
          **result.to_h.slice(:original, :refined, :iterations, :feedback_history, :improved, :confidence),
          generation_model:, feedback_model_id:, cross_model: generation_model != feedback_model_id
        )
      end
    end
  end
end
