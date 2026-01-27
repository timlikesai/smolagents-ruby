require_relative "task_coordination/queries"
require_relative "task_coordination/progress"

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

          emit :coord_task_created,
               task_id: task.id,
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

          emit :coord_task_started, task_id:, active_form: task&.active_form

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

          emit :coord_task_completed, task_id:, result:, duration_ms: compute_duration_ms(task)

          @task_coordinator
        end

        def compute_duration_ms(task)
          return nil unless task

          elapsed = task.elapsed_seconds
          elapsed ? (elapsed * 1000).to_i : nil
        end

        private

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
          emit :coord_task_failed, task_id: task.id, error: e.message
        end
      end
    end
  end
end
