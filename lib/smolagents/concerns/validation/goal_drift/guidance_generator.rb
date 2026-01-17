module Smolagents
  module Concerns
    module GoalDrift
      # Generates guidance messages for drift correction.
      #
      # Produces human-readable guidance based on drift severity
      # to help agents refocus on their original task.
      module GuidanceGenerator
        private

        # Generates guidance to correct drift.
        #
        # @param task [String] Original task
        # @param level [Symbol] Drift level
        # @return [String] Guidance message
        DRIFT_TEMPLATES = {
          severe: ["CRITICAL: You have drifted far from the task. Stop and refocus.", "Original task: %s",
                   "Take a direct action toward completing this task or call final_answer."],
          moderate: ["WARNING: Your recent actions seem unrelated to the task.", "Refocus on: %s",
                     "Consider what direct action will help complete the task."],
          mild: ["Note: Recent actions may be tangential to the main task.", "Remember the goal: %s"]
        }.freeze

        def generate_drift_guidance(task, level)
          template = DRIFT_TEMPLATES[level] || DRIFT_TEMPLATES[:mild]
          format_drift_template(template, task.to_s.slice(0, 100))
        end

        def format_drift_template(template, task_summary)
          template.map { |line| line.include?("%s") ? format(line, task_summary) : line }.join("\n")
        end

        def emit_drift_event(result)
          return unless respond_to?(:emit, true)

          emit(Events::GoalDriftDetected.create(
                 level: result.level,
                 task_relevance: result.task_relevance,
                 off_topic_count: result.off_topic_count
               ))
        rescue NameError
          # Event not defined - skip
        end

        def log_drift_result(result)
          return unless @logger

          if result.critical?
            @logger.warn("Goal drift: severe", relevance: result.task_relevance.round(2))
          elsif result.concerning?
            @logger.info("Goal drift: moderate", relevance: result.task_relevance.round(2))
          elsif result.drifting?
            @logger.debug("Goal drift: mild", relevance: result.task_relevance.round(2))
          end
        end
      end
    end
  end
end
