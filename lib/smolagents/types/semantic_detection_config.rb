module Smolagents
  module Types
    # Configuration for semantic failure detection thresholds and behavior.
    #
    # SemanticDetectionConfig controls which detectors are enabled and their
    # sensitivity thresholds for the semantic circuit breaker.
    #
    # @example Default configuration
    #   config = SemanticDetectionConfig.default
    #   config.incoherence_threshold  # => 0.3
    #
    # @example Strict configuration (lower thresholds, faster detection)
    #   config = SemanticDetectionConfig.strict
    #
    # @example Permissive configuration (higher thresholds, fewer false positives)
    #   config = SemanticDetectionConfig.permissive
    #
    # @see SemanticDetectionResult Detection result type
    SemanticDetectionConfig = Data.define(
      :incoherence_threshold,      # Float - threshold for incoherence detection (default: 0.3)
      :drift_threshold,            # Float - threshold for goal drift detection (default: 0.5)
      :confidence_decay_threshold, # Float - threshold for confidence decay (default: 0.2)
      :loop_similarity_threshold,  # Float - threshold for loop similarity (default: 0.85)
      :enabled_detectors,          # Array<Symbol> - which detectors are active (default: [:all])
      :action_thresholds           # Hash - maps severity to action
    ) do
      # Default action thresholds mapping severity to recommended action.
      DEFAULT_ACTION_THRESHOLDS = {
        low: :continue,
        medium: :warn,
        high: :pause,
        critical: :abort
      }.freeze

      # Creates a default configuration with balanced thresholds.
      #
      # @return [SemanticDetectionConfig]
      def self.default
        new(
          incoherence_threshold: 0.3,
          drift_threshold: 0.5,
          confidence_decay_threshold: 0.2,
          loop_similarity_threshold: 0.85,
          enabled_detectors: [:all],
          action_thresholds: DEFAULT_ACTION_THRESHOLDS
        )
      end

      # Creates a strict configuration with lower thresholds for faster detection.
      #
      # @return [SemanticDetectionConfig]
      def self.strict
        new(
          incoherence_threshold: 0.2,
          drift_threshold: 0.3,
          confidence_decay_threshold: 0.15,
          loop_similarity_threshold: 0.75,
          enabled_detectors: [:all],
          action_thresholds: DEFAULT_ACTION_THRESHOLDS
        )
      end

      # Creates a permissive configuration with higher thresholds to reduce false positives.
      #
      # @return [SemanticDetectionConfig]
      def self.permissive
        new(
          incoherence_threshold: 0.5,
          drift_threshold: 0.7,
          confidence_decay_threshold: 0.35,
          loop_similarity_threshold: 0.92,
          enabled_detectors: [:all],
          action_thresholds: DEFAULT_ACTION_THRESHOLDS
        )
      end

      # Whether a specific detector is enabled.
      #
      # @param detector [Symbol] Detector name
      # @return [Boolean]
      def detector_enabled?(detector) = enabled_detectors.include?(:all) || enabled_detectors.include?(detector)

      # Gets the recommended action for a given severity.
      #
      # @param severity [Symbol] Severity level (:low, :medium, :high, :critical)
      # @return [Symbol] Recommended action
      def action_for(severity) = action_thresholds.fetch(severity, :continue)
    end
  end
end
