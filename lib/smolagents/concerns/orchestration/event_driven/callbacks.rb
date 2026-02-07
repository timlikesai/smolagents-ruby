module Smolagents
  module Concerns
    module Orchestration
      module EventDriven
        # Callback management for event-driven execution.
        #
        # Provides registration and invocation of callbacks for
        # step completion, task completion, and error handling.
        module Callbacks
          # Registers a callback for step completion.
          #
          # @yield [step] Called after each step completes
          # @return [self]
          def on_step_complete(&block)
            @on_step_complete_callbacks ||= []
            @on_step_complete_callbacks << block
            self
          end

          # Registers a callback for task completion.
          #
          # @yield [result] Called when task finishes
          # @return [self]
          def on_task_complete(&block)
            @on_task_complete_callbacks ||= []
            @on_task_complete_callbacks << block
            self
          end

          # Registers a callback for errors.
          #
          # @yield [error, context] Called on error
          # @return [self]
          def on_error(&block)
            @on_error_callbacks ||= []
            @on_error_callbacks << block
            self
          end

          # Clears all registered callbacks.
          # @return [self]
          def clear_callbacks
            @on_step_complete_callbacks&.clear
            @on_task_complete_callbacks&.clear
            @on_error_callbacks&.clear
            self
          end

          private

          def invoke_step_complete(step)
            @on_step_complete_callbacks&.each { |cb| safe_invoke(cb, step) }
            emit(Events::StepCompleted.create(
                   step_number: step.step_number,
                   outcome: step.final_answer? ? :final_answer : :success,
                   observations: step.observations
                 ))
          end

          def invoke_task_complete(result)
            @on_task_complete_callbacks&.each { |cb| safe_invoke(cb, result) }
            emit(Events::TaskLifecycle.create(
                   phase: :completed,
                   outcome: result.outcome,
                   output: result.output,
                   steps_taken: result.step_count
                 ))
          end

          def invoke_error(error, context = {})
            @on_error_callbacks&.each { |cb| safe_invoke(cb, error, context) }
            emit_error(error, context:)
          end

          def safe_invoke(callback, *)
            callback.call(*)
          rescue StandardError => e
            emit_error(e, context: { callback: callback.class.name })
          end
        end
      end
    end
  end
end
