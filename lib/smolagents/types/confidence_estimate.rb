module Smolagents
  module Types
    # Confidence estimate with optional semantic component.
    #
    # Provides a unified confidence scoring interface that combines syntactic
    # (schema validation) and semantic (model/entropy) confidence signals.
    # Used by routing decisions and tool execution gates.
    #
    # @example Syntactic-only confidence
    #   estimate = ConfidenceEstimate.syntactic_only(0.85, factors: { tool_exists: true })
    #   estimate.high_confidence?  # => true
    #   estimate.semantic?     # => false
    #
    # @example Combined syntactic + semantic
    #   estimate = ConfidenceEstimate.with_semantic(syntactic: 0.9, semantic: 0.7)
    #   estimate.blended  # => 0.84 (70% syntactic + 30% semantic)
    #   estimate.semantic?  # => true
    #
    # @example Pattern matching
    #   case estimate
    #   in ConfidenceEstimate[blended:] if blended >= 0.8
    #     :high_confidence
    #   in ConfidenceEstimate[blended:]
    #     :low_confidence
    #   end
    #
    ConfidenceEstimate = Data.define(:syntactic, :semantic, :blended, :factors) do
      include TypeSupport::Deconstructable

      # Creates a syntactic-only confidence estimate.
      #
      # @param score [Float] Syntactic confidence 0.0-1.0
      # @param factors [Hash] Explanation of score components
      # @return [ConfidenceEstimate]
      def self.syntactic_only(score, factors: {})
        new(syntactic: score, semantic: nil, blended: score, factors:)
      end

      # Creates a combined syntactic + semantic estimate.
      #
      # @param syntactic [Float] Syntactic confidence 0.0-1.0
      # @param semantic [Float] Semantic confidence 0.0-1.0
      # @param weight [Float] Semantic weight (default 0.3)
      # @return [ConfidenceEstimate]
      def self.with_semantic(syntactic:, semantic:, weight: 0.3)
        blended = ((1 - weight) * syntactic) + (weight * semantic)
        new(
          syntactic:,
          semantic:,
          blended: blended.clamp(0.0, 1.0),
          factors: { syntactic_weight: 1 - weight, semantic_weight: weight }
        )
      end

      # Returns true if blended confidence exceeds threshold.
      def high_confidence?(threshold: 0.8) = blended >= threshold

      # Returns true if blended confidence is below threshold.
      def low_confidence?(threshold: 0.5) = blended < threshold

      # Returns true if semantic component is present.
      def semantic? = !semantic.nil?

      # Alias for blended (compatibility with existing interfaces).
      def confidence = blended

      # Serializable hash representation.
      def to_h
        {
          syntactic:,
          semantic:,
          blended:,
          factors:
        }
      end
    end
  end
end
