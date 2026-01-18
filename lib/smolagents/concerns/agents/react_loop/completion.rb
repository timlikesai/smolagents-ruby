module Smolagents
  module Concerns
    module ReActLoop
      # Final answer detection, max steps handling, and result building.
      #
      # Extracted from {Execution} to handle:
      # - Detecting when a step contains the final answer
      # - Handling max_steps exhaustion
      # - Building the final {Types::RunResult}
      # - Emitting completion events
      #
      # @see Execution For the main loop that uses these methods
      # @see ErrorHandling For error recovery
      module Completion
        private

        def finalize(outcome, output, ctx, memory:)
          @logger.warn("Max steps reached", max_steps: @max_steps) if outcome == :max_steps_reached
          cleanup_resources
          build_result(outcome, output, ctx.finish, memory:)
        end

        def cleanup_resources
          @model.close_connections if @model.respond_to?(:close_connections)
        end

        def build_result(outcome, output, ctx, memory:)
          emit_completion_event(outcome, output, ctx) if emitting?
          RunResult.new(output:, state: outcome, steps: memory.steps.dup,
                        token_usage: ctx.total_tokens, timing: ctx.timing)
        end

        def emit_completion_event(outcome, output, ctx)
          steps = outcome == :success ? ctx.step_number : ctx.steps_completed
          emit_event(Events::TaskCompleted.create(outcome:, output:, steps_taken: steps))
        end
      end
    end
  end
end
