module Smolagents
  module Types
    # Result of semantic failure detection analysis.
    #
    # SemanticDetectionResult encapsulates the outcome of analyzing agent
    # behavior for semantic failures like incoherence, loops, goal drift,
    # or confidence decay. Provides severity scoring and recommended actions.
    #
    # @example No detection result
    #   result = SemanticDetectionResult.none
    #   result.detected?  # => false
    #
    # @example Detected failure
    #   result = SemanticDetectionResult.detected(
    #     type: :semantic_loop,
    #     confidence: 0.92,
    #     evidence: ["Repeated search(q: 'ruby') 3 times"],
    #     severity: :high,
    #     action: :pause
    #   )
    #   result.detected?    # => true
    #   result.actionable?  # => true
    #
    # @see SemanticDetectionConfig Configuration for detection thresholds
    SemanticDetectionResult = Data.define(
      :detected,           # Boolean - failure detected?
      :failure_type,       # Symbol - :incoherence, :goal_drift, :confidence_decay, :semantic_loop, nil
      :confidence,         # Float 0.0-1.0 - detection confidence
      :evidence,           # Array<String> - supporting observations
      :severity,           # Symbol - :low, :medium, :high, :critical
      :recommended_action, # Symbol - :continue, :warn, :pause, :abort
      :metadata            # Hash - extra detection context
    ) do
      # Whether a failure was detected.
      # @return [Boolean]
      def detected? = detected

      # Whether severity is critical.
      # @return [Boolean]
      def critical? = severity == :critical

      # Whether the recommended action requires intervention.
      # @return [Boolean]
      def actionable? = %i[pause abort].include?(recommended_action)

      class << self
        # Creates a result indicating no failure detected.
        #
        # @return [SemanticDetectionResult]
        def none
          new(
            detected: false,
            failure_type: nil,
            confidence: 0.0,
            evidence: [],
            severity: nil,
            recommended_action: :continue,
            metadata: {}
          )
        end

        # Creates a result indicating a detected failure.
        #
        # @param type [Symbol] Failure type (:incoherence, :goal_drift, :confidence_decay, :semantic_loop)
        # @param confidence [Float] Detection confidence (0.0-1.0)
        # @param evidence [Array<String>] Supporting observations
        # @param severity [Symbol] Severity level (:low, :medium, :high, :critical)
        # @param action [Symbol] Recommended action (:continue, :warn, :pause, :abort)
        # @param metadata [Hash] Additional context
        # @return [SemanticDetectionResult]
        def detected(type:, confidence:, evidence:, severity:, action:, metadata: {})
          new(
            detected: true,
            failure_type: type,
            confidence: confidence.clamp(0.0, 1.0),
            evidence: Array(evidence),
            severity:,
            recommended_action: action,
            metadata:
          )
        end
      end
    end
  end
end
