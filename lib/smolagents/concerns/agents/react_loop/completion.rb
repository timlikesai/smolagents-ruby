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
      module Completion
        private

        def finalize_error(error, ctx, memory:)
          @logger.error("Agent error", error: error.message, backtrace: error.backtrace.first(3))
          cleanup_resources
          build_result(:error, nil, ctx.finish, memory:)
        end

        def finalize(outcome, output, ctx, memory:)
          # NOTE: TaskCompleted event (emitted in build_result) captures max_steps_reached outcome
          complete_root_goal(output) if should_complete_root_goal?(outcome)
          cleanup_resources
          build_result(outcome, output, ctx.finish, memory:)
        end

        # Check if root goal should be completed.
        # @param outcome [Symbol] The task outcome (:success, :max_steps_reached, etc.)
        # @return [Boolean] true if goal completion is available and outcome is success
        def should_complete_root_goal?(outcome)
          respond_to?(:current_goal) && outcome == :success && current_goal&.root?
        end

        def complete_root_goal(output)
          goal = current_goal
          complete_goal(goal, evidence: output.to_s)
          emit(Events::GoalCompleted.create(goal:, evidence: output.to_s)) if emitting?
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
          emit(Events::TaskCompleted.create(outcome:, output:, steps_taken: steps))
        end
      end
    end
  end
end
