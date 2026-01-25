module Smolagents
  module Concerns
    module Orchestration
      module EventDriven
        # Async step execution for event-driven agents.
        #
        # Transforms synchronous step calls into work items that are
        # dispatched through the orchestrator.
        module AsyncStep
          # Executes a step asynchronously through the orchestrator.
          #
          # @param task [String] Task description
          # @param step_number [Integer] Current step number
          # @yield [step] Called when step completes
          # @return [String] Work item ID for tracking
          def execute_step_async(task, step_number:, &on_complete)
            work_item = build_step_work_item(task, step_number)
            register_step_callback(work_item.id, on_complete)
            dispatch_step(work_item)
            work_item.id
          end

          # Cancels a pending async step.
          #
          # @param work_item_id [String] Work item to cancel
          # @return [Boolean] True if cancelled
          def cancel_step_async(work_item_id)
            @step_callbacks&.delete(work_item_id)
            @orchestrator&.remove_work(work_item_id)
          end

          private

          def build_step_work_item(task, step_number)
            Types::WorkItem.agent_step(
              task:,
              step_number:,
              agent_id: object_id,
              context: { memory_stats: @memory&.stats },
              deadline: step_deadline
            )
          end

          def register_step_callback(work_item_id, callback)
            @step_callbacks ||= {}
            @step_callbacks[work_item_id] = callback
          end

          def dispatch_step(work_item)
            emit(Events::AgentStepRequested.create(
                   agent_id: object_id.to_s,
                   step_number: work_item.payload[:step_number],
                   task: work_item.payload[:task]
                 ))

            # Always execute steps locally - orchestrator is for event routing only.
            # Agent steps require the agent's context (memory, model, tools).
            execute_step_fallback(work_item)
          end

          def execute_step_fallback(work_item)
            Thread.new do
              result = execute_agent_step(work_item)
              handle_step_result(result)
            rescue StandardError => e
              error_result = build_step_error(work_item, e, Time.now)
              handle_step_result(error_result)
            end
          end

          def handle_step_result(result)
            callback = @step_callbacks&.delete(result.work_item_id)
            return unless callback

            if result.success?
              callback.call(result.value)
            else
              handle_step_error(result.error, result.work_item_id)
            end
          end

          def handle_step_error(error, work_item_id)
            emit_error(error, context: { work_item_id: })
          end

          def step_deadline
            return nil unless @step_timeout

            Time.now + @step_timeout
          end
        end
      end
    end
  end
end
