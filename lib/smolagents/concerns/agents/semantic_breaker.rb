require_relative "semantic_breaker/analysis"
require_relative "semantic_breaker/detectors"

module Smolagents
  module Concerns
    module Agents
      # Semantic Circuit Breaker - catches meaning-based failures.
      #
      # Unlike technical circuit breakers that catch API errors, this concern
      # detects semantic failures in agent behavior:
      #
      # - **Incoherence**: Response doesn't follow logically from context
      # - **Goal drift**: Agent wandering from original task
      # - **Confidence decay**: Decreasing certainty in outputs
      # - **Semantic loops**: Same meaning expressed differently
      #
      # @example Basic usage
      #   class MyAgent
      #     include Concerns::Agents::SemanticBreaker
      #
      #     def initialize
      #       setup_semantic_breaker
      #     end
      #   end
      #
      # @example With custom thresholds
      #   config = Types::SemanticDetectionConfig.strict
      #   setup_semantic_breaker(config)
      #
      # @see Types::SemanticDetectionConfig For configuration options
      # @see Types::SemanticDetectionResult For detection results
      module SemanticBreaker
        include Events::Emitter
        include Analysis
        include Detectors

        # Maximum consecutive failures before breaker trips.
        DEFAULT_FAILURE_THRESHOLD = 3

        def self.included(base)
          base.attr_reader :semantic_config, :semantic_state
        end

        # Initialize semantic detection.
        #
        # @param config [SemanticDetectionConfig] Detection configuration
        # @param failure_threshold [Integer] Consecutive failures before trip
        def setup_semantic_breaker(config = nil, failure_threshold: DEFAULT_FAILURE_THRESHOLD)
          @semantic_config = config || Types::SemanticDetectionConfig.default
          @semantic_state = initial_semantic_state(failure_threshold)
        end

        # Check for semantic failures in the current step.
        #
        # @param step [ActionStep] Current step to analyze
        # @param context [Hash] Context including task, history, etc.
        # @return [SemanticDetectionResult] Detection result
        def detect_semantic_failure(step, context)
          return Types::SemanticDetectionResult.none unless @semantic_config

          results = run_enabled_detectors(step, context)
          result = aggregate_detections(results)

          handle_detection(result) if result.detected?
          result
        end

        # Called when breaker trips due to threshold exceeded.
        #
        # @param result [SemanticDetectionResult] Final detection result
        def on_semantic_breaker_tripped(result)
          action = determine_action(result.severity)
          emit :semantic_breaker_tripped,
               failure_type: result.failure_type,
               severity: result.severity,
               consecutive_failures: @semantic_state[:consecutive_failures],
               action_taken: action
        end

        # Reset the breaker to healthy state.
        #
        # @param reason [String, nil] Reason for reset
        def reset_semantic_breaker(reason = nil)
          previous_count = @semantic_state[:consecutive_failures]
          return if previous_count.zero?

          @semantic_state = initial_semantic_state(@semantic_state[:failure_threshold])
          emit :semantic_breaker_reset, previous_failure_count: previous_count, recovery_reason: reason
        end

        private

        def initial_semantic_state(threshold)
          {
            consecutive_failures: 0,
            failure_threshold: threshold,
            confidence_history: [],
            semantic_hashes: []
          }
        end

        def build_detection(type, confidence, evidence)
          severity = severity_for_confidence(confidence)
          action = @semantic_config.action_for(severity)
          Types::SemanticDetectionResult.detected(type:, confidence:, evidence:, severity:, action:)
        end

        def aggregate_detections(results)
          detected = results.select(&:detected?)
          return Types::SemanticDetectionResult.none if detected.empty?

          detected.max_by(&:confidence)
        end

        def handle_detection(result)
          emit_failure_detected(result)
          update_failure_state(result)
          on_semantic_breaker_tripped(result) if breaker_should_trip?
        end

        def emit_failure_detected(result)
          emit :semantic_failure_detected,
               failure_type: result.failure_type,
               confidence: result.confidence,
               severity: result.severity,
               evidence: result.evidence,
               recommended_action: result.recommended_action
        end

        def update_failure_state(result)
          @semantic_state[:consecutive_failures] = result.detected? ? @semantic_state[:consecutive_failures] + 1 : 0
        end

        def breaker_should_trip? = @semantic_state[:consecutive_failures] >= @semantic_state[:failure_threshold]

        def determine_action(severity) = severity == :critical ? :aborted : :paused

        def severity_for_confidence(confidence)
          case confidence
          when 0.9..1.0 then :critical
          when 0.7...0.9 then :high
          when 0.5...0.7 then :medium
          else :low
          end
        end
      end
    end
  end
end
