module Smolagents
  module Concerns
    module GoalDrift
      # Analyzes steps to detect goal drift.
      #
      # Orchestrates term extraction and similarity calculation to
      # determine if recent actions are drifting from the original task.
      module DriftAnalyzer
        private

        # Checks for goal drift in recent steps.
        #
        # @param task [String] The original task
        # @param recent_steps [Array<ActionStep>] Recent action steps
        # @return [DriftResult] Drift detection result
        # rubocop:disable Metrics/AbcSize -- multi-step analysis algorithm
        def check_goal_drift(task, recent_steps)
          return DriftResult.on_track unless @drift_config&.enabled

          steps = Array(recent_steps).last(@drift_config.window_size)
          return DriftResult.on_track if steps.empty?

          relevances = steps.map { |step| calculate_step_relevance(task, step) }
          avg_relevance = relevances.sum / relevances.size.to_f
          off_topic_count = count_consecutive_off_topic(relevances)
          level = determine_drift_level(avg_relevance, off_topic_count)

          build_drift_result(level, avg_relevance, off_topic_count, task)
        end
        # rubocop:enable Metrics/AbcSize

        # Builds the appropriate drift result.
        def build_drift_result(level, avg_relevance, off_topic_count, task)
          if level == :none
            DriftResult.on_track(task_relevance: avg_relevance)
          else
            DriftResult.drift_detected(
              level:,
              off_topic_count:,
              task_relevance: avg_relevance,
              guidance: generate_drift_guidance(task, level)
            )
          end
        end

        # Determines drift level from metrics.
        #
        # @param avg_relevance [Float] Average task relevance
        # @param off_topic_count [Integer] Consecutive off-topic steps
        # @return [Symbol] Drift level
        def determine_drift_level(avg_relevance, off_topic_count)
          max_tangent = @drift_config.max_tangent_steps

          if off_topic_count >= max_tangent + 2 || avg_relevance < 0.15
            :severe
          elsif off_topic_count >= max_tangent || avg_relevance < 0.25
            :moderate
          elsif off_topic_count >= max_tangent - 1 || avg_relevance < 0.35
            :mild
          else
            :none
          end
        end

        # Executes drift check if configured and handles result.
        #
        # @param task [String] Original task
        # @param recent_steps [Array<ActionStep>] Recent steps
        # @yield [DriftResult] If block given and drifting, yields result
        # @return [DriftResult, nil] Result or nil if disabled
        def execute_drift_check_if_needed(task, recent_steps)
          return nil unless @drift_config&.enabled

          result = check_goal_drift(task, recent_steps)
          emit_drift_event(result) if result.drifting?
          log_drift_result(result)
          yield result if block_given? && result.drifting?
          result
        end
      end
    end
  end
end
