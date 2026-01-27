module Smolagents
  module Concerns
    module Agents
      module TaskCoordination
        # Query methods for task coordination.
        #
        # Queries provides a structured API for inspecting task state,
        # finding actionable tasks, and checking completion status.
        #
        # @example Checking task status
        #   status = agent.task_status
        #   status.total        #=> 12
        #   status.completed    #=> 5
        #   status.actionable   #=> [task1, task2]
        #
        # @see Types::TaskStatus For status structure
        # @see Types::Task For task predicates
        module Queries
          # @return [Types::TaskStatus] Current status snapshot
          def task_status
            @task_coordinator&.status || Types::TaskStatus.empty
          end

          # Find a task by ID.
          #
          # @param task_id [String] Task ID
          # @return [Types::Task, nil]
          def find_task(task_id)
            @task_coordinator&.get(task_id)
          end

          # @return [Array<Types::Task>] Tasks ready to execute
          def actionable_tasks
            @task_coordinator&.actionable || []
          end

          # @return [Types::Task, nil] Next task by priority
          def next_available_task
            @task_coordinator&.next_task
          end

          # @return [Array<Types::Task>] Blocked tasks
          def blocked_tasks
            @task_coordinator&.blocked || []
          end

          # @return [Boolean] All tasks finished
          def all_tasks_done? = task_status.all_done?

          # @return [Boolean] Any tasks failed
          def any_tasks_failed? = task_status.any_failed?

          # @return [Integer] Count of open tasks
          def open_task_count = task_status.open

          # @return [Integer] Count of completed tasks
          def completed_task_count = task_status.completed_count
        end
      end
    end
  end
end
