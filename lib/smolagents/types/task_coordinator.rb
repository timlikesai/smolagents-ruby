module Smolagents
  module Types
    # Coordinator for declarative task management.
    #
    # TaskCoordinator provides a fluent API for declaring tasks with
    # dependencies, priorities, and lifecycle management. It handles
    # automatic dependency tracking and execution coordination.
    #
    # @example Basic task coordination
    #   coordinator = TaskCoordinator.create
    #
    #   t1 = coordinator.task("Create types")
    #   t2 = coordinator.task("Create events", after: t1)
    #   t3 = coordinator.task("Run tests", after: t2, priority: :high)
    #
    #   coordinator.status.total  #=> 3
    #
    # @example With execution blocks
    #   coordinator.run do |coord|
    #     coord.task("Research") { fetch_data }
    #     coord.task("Analyze", after: :previous) { analyze(results) }
    #   end
    #
    # @see Task For task structure
    # @see TaskStatus For status queries
    # @see WavePlan For parallel execution
    TaskCoordinator = Data.define(:tasks, :task_index, :last_task_id) do
      # Creates a new empty coordinator.
      #
      # @return [TaskCoordinator]
      def self.create
        new(tasks: [], task_index: {}, last_task_id: nil)
      end

      # Declares a new task.
      #
      # @param description [String] What the task does
      # @param opts [Hash] Options including :after, :priority, :active_form, :timeout, :parent_id, :metadata
      # @return [Array(TaskCoordinator, Task)] Updated coordinator and new task
      def task(description, after: nil, priority: :normal, active_form: nil, timeout: nil, parent_id: nil,
               metadata: {}, &block)
        meta = block ? metadata.merge(block:) : metadata
        new_task = Task.create(
          description:, active_form:, priority:,
          after: resolve_dependencies(after), timeout:, parent_id:, metadata: meta
        )
        [add_task(new_task), new_task]
      end

      # Adds a pre-built task.
      #
      # @param task [Task] Task to add
      # @return [TaskCoordinator] Updated coordinator
      def add_task(task)
        new_tasks = tasks + [task]
        new_index = task_index.merge(task.id => tasks.size)

        with(tasks: new_tasks, task_index: new_index, last_task_id: task.id)
      end

      # Gets a task by ID.
      #
      # @param id [String] Task ID
      # @return [Task, nil]
      def get(id)
        idx = task_index[id]
        idx ? tasks[idx] : nil
      end

      # Updates a task by ID.
      #
      # @param id [String] Task ID
      # @yield [Task] Current task
      # @yieldreturn [Task] Updated task
      # @return [TaskCoordinator] Updated coordinator
      def update(id)
        idx = task_index[id]
        return self unless idx

        updated_task = yield tasks[idx]
        new_tasks = tasks.dup
        new_tasks[idx] = updated_task

        with(tasks: new_tasks)
      end

      # Marks a task as started.
      #
      # @param id [String] Task ID
      # @return [TaskCoordinator] Updated coordinator
      def start_task(id)
        update(id, &:start)
      end

      # Marks a task as completed and unblocks dependents.
      #
      # @param id [String] Task ID
      # @param result [Object] Task result
      # @return [TaskCoordinator] Updated coordinator
      def complete_task(id, result: nil)
        coord = update(id) { |t| t.complete(result:) }
        coord.unblock_dependents(id)
      end

      # Marks a task as failed.
      #
      # @param id [String] Task ID
      # @param error [String] Error message
      # @return [TaskCoordinator] Updated coordinator
      def fail_task(id, error:)
        update(id) { |t| t.fail(error:) }
      end

      # Removes a dependency from all tasks that depend on the completed task.
      #
      # @param completed_id [String] Completed task ID
      # @return [TaskCoordinator] Updated coordinator
      def unblock_dependents(completed_id)
        new_tasks = tasks.map do |task|
          task.blocked_by.include?(completed_id) ? task.unblock(completed_id) : task
        end

        with(tasks: new_tasks)
      end

      # @return [TaskStatus] Current status snapshot
      def status = TaskStatus.from_tasks(tasks)

      # @return [Integer] Total number of tasks
      def size = tasks.size

      # @return [Boolean] No tasks declared
      def empty? = tasks.empty?

      # @return [Array<Task>] Tasks ready to execute
      def actionable = tasks.select(&:actionable?)

      # @return [Task, nil] Next actionable task by priority (highest first)
      def next_task
        actionable.max_by { |t| Task.priorities.index(t.priority) }
      end

      # @return [Array<Task>] Tasks blocked by dependencies
      def blocked = tasks.select(&:blocked?)

      # @return [Array<Task>] Children of a task
      def children_of(parent_id)
        tasks.select { |t| t.parent_id == parent_id }
      end

      # Gets progress for a specific task.
      #
      # @param task_id [String] Task ID
      # @return [TaskProgress, nil]
      def progress(task_id)
        task = get(task_id)
        return nil unless task

        subtasks = children_of(task_id)
        TaskProgress.from_task(task, subtasks:)
      end

      private

      def resolve_dependencies(deps)
        return [] if deps.nil?
        return [last_task_id].compact if deps == :previous
        return [deps.id] if deps.is_a?(Task)
        return [deps] if deps.is_a?(String)
        return deps.flat_map { |d| resolve_dependencies(d) } if deps.is_a?(Array)

        raise ArgumentError, "Invalid dependency: #{deps.inspect}"
      end
    end
  end
end
