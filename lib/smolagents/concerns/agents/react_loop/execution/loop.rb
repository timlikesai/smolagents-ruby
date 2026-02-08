module Smolagents
  module Concerns
    module ReActLoop
      module Execution
        # Core step iteration logic for the ReAct loop.
        #
        # Handles fiber context, step iteration, and completion detection.
        # Monitoring and observability are in the separate Monitoring concern.
        #
        # @see Monitoring For event emission and observability
        # @see Completion For result building and error recovery
        module Loop
          private

          # Execute task within a fiber, managing step loop.
          # @param task [String] Task description
          # @param additional_prompting [String] Extra context for model
          # @param images [Array] Image data for multi-modal models
          # @param memory [AgentMemory] Conversation and step history
          # @return [RunResult] Final result after all steps
          def fiber_loop(task:, additional_prompting:, images:, memory: @memory)
            with_fiber_context { execute_fiber_loop(task, additional_prompting, images, memory:) }
          end

          # Set and clean up fiber execution context.
          # @yield Block to execute within fiber context
          # @return [Object] Yield result
          def with_fiber_context
            Control::FiberControl.set_fiber_context(true)
            yield
          ensure
            Control::FiberControl.set_fiber_context(false)
          end

          # Run the fiber loop with task preparation and error handling.
          # @param task [String] Task description
          # @param additional_prompting [String] Extra context
          # @param images [Array] Image data
          # @param memory [AgentMemory] Conversation history
          # @return [RunResult] Final result
          def execute_fiber_loop(task, additional_prompting, images, memory:)
            prepare_task(task, additional_prompting:, images:)
            run_steps(task, RunContext.start, memory:)
          rescue StandardError => e
            finalize_error(e, @ctx, memory:)
          end

          # Main step execution loop.
          # @param task [String] Task description
          # @param ctx [RunContext] Current execution context
          # @param memory [AgentMemory] Conversation history
          # @return [RunResult] Final result from finalize
          def run_steps(task, ctx, memory:)
            @ctx = ctx
            execute_initial_planning(task) { |u| ctx = ctx.add_tokens(u) } if should_execute_initial_planning?
            until ctx.exceeded?(@max_steps)
              return_if_cancelled = check_cancellation_if_enabled
              return return_if_cancelled if return_if_cancelled

              ctx = run_step_iteration(task, ctx, memory) { |result| return result }
            end
            finalize(:max_steps_reached, nil, ctx, memory:)
          end

          def run_step_iteration(task, ctx, memory)
            step, ctx = execute_single_step(task, ctx, memory)
            result = check_step_completion(task, step, ctx, memory)
            yield result if result

            @ctx = after_step(task, step, ctx)
          end

          # Execute one step and yield to caller.
          # @param task [String] Task description
          # @param ctx [RunContext] Current execution context
          # @param memory [AgentMemory] Step history
          # @return [Array] [Step, updated RunContext]
          def execute_single_step(task, ctx, memory)
            step, ctx = execute_step_with_monitoring(task, ctx, memory:)
            check_and_handle_repetition(memory.action_steps, memory:)
            Fiber.yield(step)
            [step, ctx]
          end

          # Check if step completes the task or requires evaluation.
          # @param task [String] Task description
          # @param step [ActionStep] Completed step
          # @param ctx [RunContext] Current context
          # @param memory [AgentMemory] History
          # @return [RunResult, nil] Result if task is done, nil if continuing
          def check_step_completion(task, step, ctx, memory)
            if step.final_answer?
              return nil unless validate_completion(step, task, memory:)

              return finalize(:success, step.action_output, ctx, memory:)
            end
            return unless (r = execute_evaluation_if_needed(task, step, ctx.step_number))

            @ctx = ctx.add_tokens(r.token_usage) if r.token_usage
            finalize(:success, evaluation_answer(step, r), ctx, memory:) if r.goal_achieved?
          end

          # Extract answer for evaluation completion.
          # Prefers structured action_output over evaluator's text extraction.
          # Falls back to evaluator answer only when action_output is nil.
          def evaluation_answer(step, evaluation_result)
            step.action_output.nil? ? evaluation_result.answer : step.action_output
          end

          # No-op stub for completion validation (opt-in via CompletionValidation)
          # @return [Boolean] true to allow completion
          def validate_completion(_step, _task, **) = true # rubocop:disable Naming/PredicateMethod -- stub for mixin override, returns boolean

          # Handle post-step operations like planning updates.
          # @param task [String] Task description
          # @param step [ActionStep] Completed step
          # @param ctx [RunContext] Current context
          # @return [RunContext] Advanced context
          def after_step(task, step, ctx)
            if should_execute_planning_update?(ctx.step_number)
              execute_planning_update(task, step, ctx.step_number) { |u| ctx = ctx.add_tokens(u) }
            end
            ctx.advance
          end

          # No-op stubs for opt-in concerns (Planning overrides these)
          def should_execute_initial_planning? = false
          def should_execute_planning_update?(_step_number) = false
          def execute_planning_update(_task, _step, _step_number); end
          def execute_initial_planning(_task); end

          # No-op stub for repetition detection (opt-in via Repetition concern)
          # @param _steps [Array<ActionStep>] Recent action steps to check for repetition
          # @param memory [#add_system_message, nil] Optional memory for adding guidance messages
          def check_and_handle_repetition(_steps, memory: nil); end

          # No-op stub for evaluation (opt-in via Evaluation concern)
          def execute_evaluation_if_needed(_task, _step, _step_count) = nil

          # No-op stub for cancellation (opt-in via Cancellation concern)
          # @return [Types::RunResult, nil] nil to continue
          def check_cancellation_if_enabled = nil
        end
      end
    end
  end
end
