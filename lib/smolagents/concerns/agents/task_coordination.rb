module Smolagents
  module Concerns
    module Agents
      # Task coordination for agents with dependency management.
      #
      # TaskCoordination provides a declarative DSL for defining tasks
      # with dependencies, priorities, and lifecycle tracking. It builds
      # on the event system for progress updates and completion signals.
      #
      # @example Including in an agent
      #   class MyAgent
      #     include Concerns::Agents::TaskCoordination
      #
      #     def initialize
      #       initialize_task_coordination
      #     end
      #   end
      #
      # @example Coordinated execution
      #   agent.run_coordinated("Build feature") do |coord|
      #     types = coord.task("Create types")
      #     tests = coord.task("Write tests", after: types)
      #   end
      #
      # @see Types::TaskCoordinator For coordinator API
      # @see Types::Task For task structure
      module TaskCoordination
        # Query methods for inspecting task state.
        #
        # Provides read-only accessors for task status, filtering,
        # and lookup without modifying coordinator state.
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

        # Progress tracking and reporting for coordinated tasks.
        #
        # Provides methods for querying task progress, emitting
        # progress events, and generating human-readable summaries.
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

            emit :coord_task_lifecycle, phase: :progress,
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
        end

        include Events::Emitter
        include Queries
        include Progress

        # Initialize task coordination state.
        def initialize_task_coordination
          @task_coordinator = Types::TaskCoordinator.create
        end

        # @return [Types::TaskCoordinator] Current coordinator
        attr_reader :task_coordinator

        # Run a task with coordination enabled.
        #
        # @param description [String] What the task does
        # @yield [Types::TaskCoordinator] Coordinator for declaring subtasks
        # @return [Object] Final result
        def run_coordinated(description, &block)
          root_task = declare_task(description, priority: :normal)

          if block
            @task_coordinator, _task = @task_coordinator.task(
              description, priority: :normal
            )
            yield(@task_coordinator)
          end

          execute_coordinated_tasks(root_task)
        end

        # Declare a task in the coordinator.
        #
        # @param description [String] What the task does
        # @param after [Task, Array<Task>, :previous, nil] Dependencies
        # @param priority [Symbol] :low, :normal, :high, :critical
        # @param active_form [String, nil] Present continuous form
        # @param timeout [Integer, nil] Timeout in seconds
        # @param metadata [Hash] Additional task metadata
        # @return [Types::Task] The declared task
        def declare_task(description, after: nil, priority: :normal, active_form: nil, timeout: nil, metadata: {})
          @task_coordinator, task = @task_coordinator.task(
            description, after:, priority:, active_form:, timeout:, metadata:
          )

          emit :coord_task_lifecycle,
               task_id: task.id,
               phase: :created,
               description: task.description,
               priority: task.priority,
               dependencies: task.dependencies

          task
        end

        # Start executing a task.
        #
        # @param task_id [String] Task to start
        # @return [Types::TaskCoordinator] Updated coordinator
        def start_task(task_id)
          @task_coordinator = @task_coordinator.start_task(task_id)
          task = @task_coordinator.get(task_id)

          emit :coord_task_lifecycle, task_id:, phase: :started, active_form: task&.active_form

          @task_coordinator
        end

        # Complete a task with optional result.
        #
        # @param task_id [String] Task to complete
        # @param result [Object] Task result
        # @return [Types::TaskCoordinator] Updated coordinator
        def complete_task(task_id, result: nil)
          task = @task_coordinator.get(task_id)
          @task_coordinator = @task_coordinator.complete_task(task_id, result:)

          emit :coord_task_lifecycle, task_id:, phase: :completed, result:, duration_ms: compute_duration_ms(task)

          @task_coordinator
        end

        def compute_duration_ms(task)
          return nil unless task

          elapsed = task.elapsed_seconds
          elapsed ? (elapsed * 1000).to_i : nil
        end

        private

        def subscribed_to?(event_type) = respond_to?(:event_subscribed?) && event_subscribed?(event_type)

        def execute_coordinated_tasks(root_task)
          start_task(root_task.id)

          until @task_coordinator.status.all_done?
            next_task = @task_coordinator.next_task
            break unless next_task

            execute_single_task(next_task)
          end

          complete_task(root_task.id)
          @task_coordinator.get(root_task.id)&.result
        end

        def execute_single_task(task)
          start_task(task.id)

          result = task.metadata[:block]&.call

          complete_task(task.id, result:)
        rescue StandardError => e
          @task_coordinator = @task_coordinator.fail_task(task.id, error: e.message)
          emit :coord_task_lifecycle, task_id: task.id, phase: :failed, error: e.message
        end
      end
    end
  end
end
