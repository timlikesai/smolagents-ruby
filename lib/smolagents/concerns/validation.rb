require_relative "validation/execution_oracle"
require_relative "validation/goal_drift"

# Validation concerns for external feedback and oracle patterns.
#
# Small models cannot self-correct reasoning errors, but CAN correct
# based on external feedback. These concerns provide structured validation
# and feedback mechanisms.
#
# @!group Concern Dependency Graph
#
# == Dependency Matrix
#
#   | Concern          | Depends On                | Depended By     | Auto-Includes                       |
#   |------------------|---------------------------|-----------------|-------------------------------------|
#   | ExecutionOracle  | -                         | ErrorFeedback   | ErrorParser, SuggestionGenerator,   |
#   |                  |                           |                 | ConfidenceScorer                    |
#   | GoalDrift        | -                         | -               | TermExtractor, SimilarityCalculator,|
#   |                  |                           |                 | GuidanceGenerator, DriftAnalyzer    |
#
# == Sub-concern Composition
#
#   ExecutionOracle
#       |
#       +-- ErrorParser: classify_error(), parse_error_details()
#       |   - Provides: Error pattern matching and classification
#       |   - Defines: ERROR_PATTERNS constant
#       |
#       +-- SuggestionGenerator: generate_suggestion()
#       |   - Provides: Actionable suggestions for each error type
#       |
#       +-- ConfidenceScorer: calculate_confidence()
#           - Provides: Confidence scores for feedback quality
#
#   GoalDrift
#       |
#       +-- TermExtractor: extract_task_terms(), extract_action_terms()
#       |   - Provides: Key term extraction from task/actions
#       |
#       +-- SimilarityCalculator: calculate_similarity()
#       |   - Provides: Term-based similarity scoring
#       |
#       +-- GuidanceGenerator: generate_drift_guidance()
#       |   - Provides: Refocusing guidance when drifting
#       |
#       +-- DriftAnalyzer: analyze_drift()
#           - Provides: Main drift detection logic
#
# == Types Defined
#
# *ExecutionOracle*:
# - ExecutionFeedback - Structured result (category, message, suggestion, confidence)
# - ERROR_CATEGORIES - Classification enum (:success, :syntax_error, :name_error, etc.)
#
# *GoalDrift*:
# - DriftConfig - Detection settings (enabled, window_size, thresholds)
# - DriftResult - Analysis result (level, confidence, off_topic_count, guidance)
#
# == Instance Variables Set
#
# *GoalDrift*:
# - @drift_config [DriftConfig] - Detection configuration
#
# == No External Dependencies
#
# Both validation concerns are standalone and do not require Events, Models,
# or other concern systems. They can be included in any class.
#
# @!endgroup
#
# == Concerns
#
# - {ExecutionOracle} - Parses execution results into actionable feedback
# - {GoalDrift} - Monitors task adherence and detects goal drift
#
# @example Using the execution oracle
#   include Concerns::ExecutionOracle
#
#   feedback = analyze_execution(result, code)
#   if feedback.actionable?
#     inject_feedback(feedback)
#   end
#
# @example Using goal drift detection
#   include Concerns::GoalDrift
#
#   initialize_goal_drift(drift_config: DriftConfig.default)
#   drift = check_goal_drift(task, recent_steps)
#   if drift.concerning?
#     inject_guidance(drift.guidance)
#   end
#
# @see https://arxiv.org/abs/2310.01798 "Large Language Models Cannot Self-Correct"
# @see https://arxiv.org/abs/2505.02709 "Goal drift in LLM agents"
module Smolagents
  module Concerns
    module Validation
    end
  end
end
