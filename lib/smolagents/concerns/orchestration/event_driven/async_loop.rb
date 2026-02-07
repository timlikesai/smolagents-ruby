module Smolagents
  module Concerns
    module Orchestration
      module EventDriven
        # Async loop execution for event-driven agents.
        #
        # Provides callback-based alternatives to the synchronous ReActLoop
        # that integrate with the event orchestrator.
        module AsyncLoop
          # Runs a task asynchronously with callbacks.
          #
          # @param task [String] Task to execute
          # @param on_step [Proc] Called after each step
          # @param on_complete [Proc] Called when task finishes
          # @param on_error [Proc] Called on errors
          # @return [String] Run ID for tracking # -- async setup
          def run_async(task, on_step: nil, on_complete: nil, on_error: nil)
            run_id = SecureRandom.uuid
            @async_runs ||= {}
            @async_runs[run_id] = {
              task:, step_number: 0, steps: [], on_step:,
              on_complete:, on_error:, pending_work_id: nil
            }

            emit(Events::TaskLifecycle.create(phase: :started, run_id:, task:)) if respond_to?(:emit)
            schedule_next_step(run_id)
            run_id
          end

          # Cancels an async run.
          #
          # @param run_id [String] Run to cancel
          # @return [self]
          def cancel_run(run_id)
            state = @async_runs&.delete(run_id)
            state&.dig(:pending_work_id)&.then { |id| cancel_step_async(id) }
            self
          end

          # Check if an async run is active.
          # @param run_id [String] Run ID
          # @return [Boolean]
          def async_running?(run_id)
            @async_runs&.key?(run_id) || false
          end

          private

          def schedule_next_step(run_id)
            state = @async_runs[run_id]
            return unless state
            return finalize_async_run(run_id, :max_steps) if state[:step_number] >= @max_steps

            state[:step_number] += 1
            schedule_step_execution(run_id, state)
          end

          def schedule_step_execution(run_id, state)
            work_id = execute_step_async(state[:task], step_number: state[:step_number]) do |step|
              handle_async_step_complete(run_id, step)
            end
            state[:pending_work_id] = work_id
          end

          def handle_async_step_complete(run_id, step)
            state = @async_runs[run_id]
            return unless state

            update_step_state(state, step)
            process_step_outcome(run_id, step)
          rescue StandardError => e
            handle_async_error(run_id, e)
          end

          def update_step_state(state, step)
            state[:pending_work_id] = nil
            state[:steps] << step
            state[:on_step]&.call(step)
            invoke_step_complete(step)
          end

          def process_step_outcome(run_id, step)
            if step.final_answer?
              finalize_async_run(run_id, :success, step.action_output)
            else
              schedule_next_step(run_id)
            end
          end

          def finalize_async_run(run_id, outcome, output = nil)
            state = @async_runs&.delete(run_id)
            return unless state

            result = build_run_result(outcome, output, state[:steps])
            state[:on_complete]&.call(result)
            invoke_task_complete(result)
          end

          def build_run_result(outcome, output, steps)
            case outcome
            when :success then Types::RunResult.success(output:, steps:)
            when :max_steps then Types::RunResult.max_steps(output:, steps:)
            else Types::RunResult.error(output:, steps:)
            end
          end

          def handle_async_error(run_id, error)
            state = @async_runs&.delete(run_id)
            return unless state

            state[:on_error]&.call(error)
            invoke_error(error, { run_id: })
          end
        end
      end
    end
  end
end
