module Smolagents
  module Concerns
    module ReActLoop
      # Event emission for step and task completion.
      module EventEmitter
        private

        def emit_step_completed_event(current_step)
          return unless emitting?

          emit_event(
            Events::StepCompleted.create(
              step_number: current_step.step_number,
              outcome: step_outcome(current_step),
              observations: current_step.observations
            )
          )
        end

        def step_outcome(current_step)
          return :final_answer if current_step.is_final_answer
          return :error if current_step.respond_to?(:error) && current_step.error

          :success
        end

        def emit_task_completed_event(outcome, output, steps_taken)
          return unless emitting?

          emit_event(
            Events::TaskCompleted.create(
              outcome:,
              output:,
              steps_taken:
            )
          )
        end
      end
    end
  end
end
