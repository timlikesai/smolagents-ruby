module Smolagents
  module Types
    # Progress snapshot for a running task.
    #
    # TaskProgress captures the current state of a task and its subtasks
    # for real-time progress reporting and visualization.
    #
    # @example Getting progress
    #   progress = coordinator.progress(task_id)
    #   progress.active_form    #=> "Creating types"
    #   progress.elapsed        #=> 2.5 (seconds)
    #   progress.subtask_count  #=> 3
    #
    # @example Progress event handler
    #   agent.on(:task_progress) do |progress|
    #     puts "#{progress.active_form}... (#{progress.elapsed.round(1)}s)"
    #     progress.subtasks.each { |sub| puts "  #{sub.to_s}" }
    #   end
    #
    # @see Task For task structure
    # @see TaskStatus For aggregate status
    TaskProgress = Data.define(
      :task_id,         # String - task identifier
      :active_form,     # String - present continuous description
      :status,          # Symbol - current task status
      :elapsed,         # Float - elapsed seconds
      :subtasks,        # Array<Task> - child tasks
      :tokens_used,     # Integer, nil - estimated tokens consumed
      :progress_percent, # Float - completion percentage (0-100)
      :blocked_by,      # Array<String> - blocking task IDs
      :metadata         # Hash - additional data
    ) do
      # Creates progress from a task and its subtasks.
      #
      # @param task [Task] The task to report on
      # @param subtasks [Array<Task>] Child tasks
      # @param tokens_used [Integer, nil] Token estimate
      # @return [TaskProgress]
      def self.from_task(task, subtasks: [], tokens_used: nil)
        new(
          task_id: task.id, active_form: task.active_form, status: task.status,
          elapsed: task.elapsed_seconds || 0.0, subtasks:, tokens_used:,
          progress_percent: calculate_progress(task, subtasks),
          blocked_by: task.blocked_by, metadata: task.metadata
        )
      end

      # Calculates progress percentage based on subtask completion.
      # @api private
      def self.calculate_progress(task, subtasks)
        return 100.0 if task.completed?
        return 0.0 if subtasks.empty?

        finished = subtasks.count(&:finished?)
        (finished.to_f / subtasks.size * 100).round(1)
      end

      # @return [Boolean] Task is blocked
      def blocked? = blocked_by.any?

      # @return [Boolean] Task is in progress
      def in_progress? = status == :in_progress

      # @return [Boolean] Task is finished
      def finished? = %i[completed failed cancelled].include?(status)

      # @return [Integer] Number of subtasks
      def subtask_count = subtasks.size

      # @return [Integer] Number of completed subtasks
      def completed_subtask_count = subtasks.count(&:completed?)

      # @return [String] Formatted elapsed time
      def formatted_elapsed
        secs = elapsed.to_i
        return "#{secs}s" if secs < 60

        mins = secs / 60
        remaining_secs = secs % 60
        "#{mins}m #{remaining_secs}s"
      end

      # @return [String] Progress bar string (e.g., "[====    ] 50%")
      def progress_bar(width: 10)
        filled = (progress_percent / 100 * width).round
        bar = ("=" * filled) + (" " * (width - filled))
        "[#{bar}] #{progress_percent.round}%"
      end

      # @return [String] Summary string
      def to_s
        blocked_info = blocked? ? " [blocked]" : ""
        "#{active_form} #{progress_bar}#{blocked_info}"
      end
    end
  end
end
