module Smolagents
  module Concerns
    module Agents
      module TaskCoordination
        # Progress tracking for task coordination.
        #
        # Progress provides real-time visibility into task execution,
        # including elapsed time, subtask status, and completion percentage.
        # Events are emitted lazily only when subscribers are present.
        #
        # @example Getting progress for a task
        #   progress = agent.task_progress("task_abc123")
        #   progress.active_form     #=> "Creating types"
        #   progress.elapsed         #=> 2.5
        #   progress.progress_bar    #=> "[====      ] 40%"
        #
        # @see Types::TaskProgress For progress structure
        module Progress
          # Get progress for a specific task.
          #
          # @param task_id [String] Task ID
          # @param tokens_used [Integer, nil] Token estimate
          # @return [Types::TaskProgress, nil]
          def task_progress(task_id, _tokens_used: nil)
            @task_coordinator&.progress(task_id)
          end

          # Emit progress event if subscribers are listening.
          #
          # @param task_id [String] Task ID
          # @param tokens_used [Integer, nil] Token estimate
          # @return [void]
          def emit_task_progress(task_id, tokens_used: nil)
            return unless subscribed_to?(:task_progress)

            progress = task_progress(task_id, tokens_used:)
            return unless progress

            emit :task_progress,
                 task_id:,
                 active_form: progress.active_form,
                 elapsed: progress.elapsed,
                 progress_percent: progress.progress_percent,
                 subtask_count: progress.subtask_count,
                 blocked_by: progress.blocked_by
          end

          # @return [Float] Overall progress percentage
          def overall_progress_percent = task_status.progress_percent

          # @return [String] Formatted overall progress
          def overall_progress_bar(width: 20)
            percent = overall_progress_percent
            filled = (percent / 100 * width).round
            bar = ("=" * filled) + (" " * (width - filled))
            "[#{bar}] #{percent.round}%"
          end

          # @return [String] Summary of current task state
          def task_summary
            status = task_status
            "#{status.completed_count}/#{status.total} done, " \
              "#{status.blocked_count} blocked, " \
              "#{status.in_progress_count} running"
          end

          private

          def subscribed_to?(event_type) = respond_to?(:event_subscribed?) && event_subscribed?(event_type)
        end
      end
    end
  end
end
