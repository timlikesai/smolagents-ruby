module Smolagents
  module Concerns
    module Orchestration
      # Automatic task dispatch via event triggers.
      #
      # TaskDispatch wires task completion events to automatic work item
      # creation for dependent tasks, enabling reactive execution flow.
      #
      # @example Setting up dispatch triggers
      #   include TaskDispatch
      #   setup_task_dispatch(coordinator, queue)
      #
      #   on(:task_lifecycle) { |e| dispatch_unblocked(e.task_id) if e.completed? }
      #
      # @see WorkQueue For work item management
      # @see Types::TaskCoordinator For task management
      module TaskDispatch
        include Events::Emitter
        include Events::Consumer

        # Distribution strategies for task scheduling.
        STRATEGIES = %i[
          priority_first
          priority_first_fair
          fifo
          round_robin
        ].freeze

        # Initialize dispatch with coordinator and queue.
        #
        # @param coordinator [Types::TaskCoordinator] Task source
        # @param work_queue [WorkQueue] Destination queue
        # @param strategy [Symbol] Distribution strategy
        def initialize_task_dispatch(coordinator, work_queue, strategy: :priority_first_fair)
          @dispatch_coordinator = coordinator
          @dispatch_queue = work_queue
          @dispatch_strategy = strategy
          @dispatch_fair_count = 0

          setup_task_triggers
        end

        # Dispatch all currently actionable tasks.
        #
        # @return [Integer] Number of tasks dispatched
        def dispatch_actionable_tasks
          tasks = @dispatch_coordinator.actionable
          tasks = apply_strategy(tasks)

          tasks.each { |task| dispatch_task(task) }
          tasks.size
        end

        # Dispatch dependent tasks after completion.
        #
        # @param completed_task_id [String] Just-completed task ID
        # @return [Integer] Number of tasks dispatched
        def dispatch_unblocked(completed_task_id)
          @dispatch_coordinator = @dispatch_coordinator.unblock_dependents(completed_task_id)

          newly_actionable = @dispatch_coordinator.actionable.select do |task|
            task.blocked_by.empty? && task.pending?
          end

          newly_actionable.each { |task| dispatch_task(task) }
          newly_actionable.size
        end

        private

        def setup_task_triggers
          on(:task_lifecycle) do |event|
            next unless event.completed?

            dispatch_unblocked(event[:task_id])
          end
        end

        def dispatch_task(task)
          work_item = build_work_item(task)
          @dispatch_queue.enqueue(work_item)

          emit :coord_task_lifecycle, phase: :dispatched,
                                      task_id: task.id, priority: task.priority, work_item_id: work_item.id
        end

        def build_work_item(task)
          Types::WorkItem.new(
            id: "work_#{task.id}", type: :agent_step,
            payload: { task_id: task.id, description: task.description },
            priority: map_priority(task.priority), created_at: Time.now,
            status: :pending, metadata: task.metadata
          )
        end

        def apply_strategy(tasks)
          return tasks unless STRATEGIES.include?(@dispatch_strategy)

          send(:"apply_#{@dispatch_strategy}", tasks)
        end

        def apply_priority_first(tasks) = sort_by_priority(tasks)
        def apply_priority_first_fair(tasks) = sort_by_priority_fair(tasks)
        def apply_fifo(tasks) = tasks
        def apply_round_robin(tasks) = tasks.rotate(@dispatch_fair_count)

        def sort_by_priority(tasks)
          tasks.sort_by { |t| Types::Task.priorities.index(t.priority) }
        end

        def sort_by_priority_fair(tasks)
          sorted = sort_by_priority(tasks)
          @dispatch_fair_count += 1

          if @dispatch_fair_count >= 5 && sorted.size > 1
            @dispatch_fair_count = 0
            [sorted.last, *sorted[0..-2]]
          else
            sorted
          end
        end

        def map_priority(task_priority)
          Types::Task.priorities.include?(task_priority) ? task_priority : :normal
        end
      end
    end
  end
end
