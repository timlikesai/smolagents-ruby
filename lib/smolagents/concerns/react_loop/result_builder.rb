module Smolagents
  module Concerns
    module ReActLoop
      # Result finalization and cleanup.
      module ResultBuilder
        private

        def finalize(outcome, output, context)
          finished = context.finish
          @logger.warn("Max steps reached", max_steps: @max_steps) if outcome == :max_steps_reached
          cleanup_resources
          build_result(outcome, output, finished)
        end

        def finalize_error(error, context)
          @logger.error("Agent error", error: error.message, backtrace: error.backtrace.first(3))
          cleanup_resources
          build_result(:error, nil, context.finish)
        end

        def cleanup_resources
          @model.close_connections if @model.respond_to?(:close_connections)
        end

        def build_result(outcome, output, context)
          steps_completed = outcome == :success ? context.step_number : context.steps_completed
          emit_task_completed_event(outcome, output, steps_completed)
          RunResult.new(
            output:,
            state: outcome,
            steps: @memory.steps.dup,
            token_usage: context.total_tokens,
            timing: context.timing
          )
        end
      end
    end
  end
end
