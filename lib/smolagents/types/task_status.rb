module Smolagents
  module Types
    # Snapshot of task coordinator status.
    #
    # TaskStatus provides a structured view of all tasks in a coordinator,
    # with counts by status and convenience methods for querying.
    #
    # @example Getting status from coordinator
    #   status = coordinator.status
    #   status.total       #=> 12
    #   status.completed   #=> 5
    #   status.open        #=> 7
    #   status.blocked     #=> [task1, task2]
    #
    # @example Checking progress
    #   status.progress_percent  #=> 41.6
    #   status.all_done?         #=> false
    #
    # @see TaskCoordinator For task management
    # @see Task For individual task structure
    TaskStatus = Data.define(
      :tasks,           # Array<Task> - all tasks
      :pending_count,   # Integer - pending tasks
      :in_progress_count, # Integer - in progress tasks
      :completed_count, # Integer - completed tasks
      :failed_count,    # Integer - failed tasks
      :cancelled_count, # Integer - cancelled tasks
      :blocked_count,   # Integer - blocked tasks
      :snapshot_at      # Time - when snapshot was taken
    ) do
      # Creates a status snapshot from tasks.
      #
      # @param tasks [Array<Task>] All tasks to summarize
      # @return [TaskStatus]
      def self.from_tasks(tasks)
        tasks = Array(tasks)
        counts = count_by_status(tasks)

        new(tasks:, **counts, snapshot_at: Time.now)
      end

      def self.count_by_status(tasks)
        {
          pending_count: tasks.count(&:pending?), in_progress_count: tasks.count(&:in_progress?),
          completed_count: tasks.count(&:completed?), failed_count: tasks.count(&:failed?),
          cancelled_count: tasks.count(&:cancelled?), blocked_count: tasks.count(&:blocked?)
        }
      end

      # @return [TaskStatus] Empty status
      def self.empty
        new(
          tasks: [],
          pending_count: 0,
          in_progress_count: 0,
          completed_count: 0,
          failed_count: 0,
          cancelled_count: 0,
          blocked_count: 0,
          snapshot_at: Time.now
        )
      end

      # @return [Integer] Total number of tasks
      def total = tasks.size

      # @return [Integer] Number of open tasks (pending + in_progress)
      def open = pending_count + in_progress_count

      # @return [Integer] Number of finished tasks (completed + failed + cancelled)
      def finished = completed_count + failed_count + cancelled_count

      # @return [Float] Progress as percentage (0-100)
      def progress_percent
        return 0.0 if total.zero?

        (finished.to_f / total * 100).round(1)
      end

      # @return [Boolean] All tasks finished
      def all_done? = finished == total && total.positive?

      # @return [Boolean] Any tasks failed
      def any_failed? = failed_count.positive?

      # @return [Boolean] No tasks exist
      def empty? = tasks.empty?

      # @return [Array<Task>] Tasks that are blocked
      def blocked = tasks.select(&:blocked?)

      # @return [Array<Task>] Tasks that are actionable (pending, not blocked)
      def actionable = tasks.select(&:actionable?)

      # @return [Array<Task>] Tasks that are in progress
      def in_progress = tasks.select(&:in_progress?)

      # @return [Array<Task>] Tasks that are pending (not started)
      def pending = tasks.select(&:pending?)

      # @return [Array<Task>] Tasks that are completed
      def completed = tasks.select(&:completed?)

      # @return [Array<Task>] Tasks that failed
      def failed = tasks.select(&:failed?)

      # @return [Task, nil] Next actionable task by priority (highest first)
      def next_available
        actionable.max_by { |t| Task.priorities.index(t.priority) }
      end

      # Find a task by ID.
      # @param id [String] Task ID
      # @return [Task, nil]
      def find_task(id) = tasks.find { |t| t.id == id }

      # @return [String] Summary string
      def to_s
        "Tasks: #{completed_count}/#{total} done, #{blocked_count} blocked, #{in_progress_count} running"
      end
    end
  end
end
