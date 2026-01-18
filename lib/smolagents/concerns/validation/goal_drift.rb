require_relative "goal_drift/term_extractor"
require_relative "goal_drift/similarity_calculator"
require_relative "goal_drift/guidance_generator"
require_relative "goal_drift/drift_analyzer"

module Smolagents
  module Concerns
    # Goal Drift Detection for monitoring task adherence.
    #
    # Research shows agents can gradually drift from their original task,
    # especially in multi-step interactions. This concern monitors action
    # sequences and flags when behavior deviates from the goal.
    #
    # @see https://arxiv.org/abs/2505.02709 Goal drift in LLM agents
    #
    # @example Basic usage
    #   include GoalDrift
    #
    #   drift = check_goal_drift(task, recent_steps)
    #   if drift.drifting?
    #     inject_guidance("Refocus on: #{task}")
    #   end
    module GoalDrift
      # Drift severity levels.
      DRIFT_LEVELS = %i[none mild moderate severe].freeze

      # Configuration for drift detection.
      #
      # @!attribute [r] enabled
      #   @return [Boolean] Whether drift detection is enabled
      # @!attribute [r] window_size
      #   @return [Integer] Number of recent steps to analyze
      # @!attribute [r] similarity_threshold
      #   @return [Float] Minimum task-action similarity (0.0-1.0)
      # @!attribute [r] max_tangent_steps
      #   @return [Integer] Max consecutive off-topic steps before flagging
      DriftConfig = Data.define(:enabled, :window_size, :similarity_threshold, :max_tangent_steps) do
        def self.default
          new(enabled: true, window_size: 5, similarity_threshold: 0.3, max_tangent_steps: 3)
        end

        def self.disabled
          new(enabled: false, window_size: 0, similarity_threshold: 0.0, max_tangent_steps: 0)
        end

        def self.strict
          new(enabled: true, window_size: 3, similarity_threshold: 0.4, max_tangent_steps: 2)
        end
      end

      # Result of drift detection analysis.
      #
      # @!attribute [r] level
      #   @return [Symbol] Drift severity (:none, :mild, :moderate, :severe)
      # @!attribute [r] confidence
      #   @return [Float] Confidence in the assessment (0.0-1.0)
      # @!attribute [r] off_topic_count
      #   @return [Integer] Number of consecutive off-topic steps
      # @!attribute [r] task_relevance
      #   @return [Float] Overall relevance to original task (0.0-1.0)
      # @!attribute [r] guidance
      #   @return [String, nil] Suggested guidance if drifting
      DriftResult = Data.define(:level, :confidence, :off_topic_count, :task_relevance, :guidance) do
        def drifting? = level != :none
        def concerning? = %i[moderate severe].include?(level)
        def critical? = level == :severe

        class << self
          def on_track(task_relevance: 1.0)
            new(level: :none, confidence: 0.9, off_topic_count: 0, task_relevance:, guidance: nil)
          end

          def drift_detected(level:, off_topic_count:, task_relevance:, guidance:)
            confidence = { mild: 0.6, moderate: 0.75, severe: 0.9 }.fetch(level, 0.5)
            new(level:, confidence:, off_topic_count:, task_relevance:, guidance:)
          end
        end
      end

      def self.included(base)
        base.include(TermExtractor)
        base.include(SimilarityCalculator)
        base.include(GuidanceGenerator)
        base.include(DriftAnalyzer)
        base.attr_reader :drift_config
      end

      private

      def initialize_goal_drift(drift_config: nil)
        @drift_config = drift_config || DriftConfig.disabled
      end
    end
  end
end
