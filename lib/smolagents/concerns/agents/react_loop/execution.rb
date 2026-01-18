require_relative "completion"
require_relative "error_handling"

module Smolagents
  module Concerns
    module ReActLoop
      # Main loop execution, step monitoring, and fiber context management.
      #
      # Implements the Fiber-based execution loop that:
      # - Runs steps until completion or max_steps
      # - Handles planning and evaluation phases
      # - Emits events for each step
      #
      # == Composition
      #
      # Auto-includes these sub-concerns:
      # - {Completion} - finalize(), build_result(), cleanup_resources()
      # - {ErrorHandling} - finalize_error()
      #
      # == Extension Points (No-op Stubs)
      #
      # Execution defines no-op stub methods that opt-in concerns override:
      #
      #   | Stub Method                      | Overriding Concern | Purpose                    |
      #   |----------------------------------|--------------------|----------------------------|
      #   | execute_planning_step_if_needed  | Planning           | Periodic replanning        |
      #   | execute_initial_planning_if_needed | Planning         | Pre-act planning           |
      #   | check_and_handle_repetition      | Repetition         | Loop detection             |
      #   | execute_evaluation_if_needed     | Evaluation         | Metacognition phase        |
      #
      # This stub pattern allows concerns to be layered without tight coupling.
      # Include the opt-in concern AFTER ReActLoop to override the stub.
      #
      # == Fiber Context
      #
      # The execution loop runs within a Fiber context tracked via Thread-local:
      # - Uses thread_variable_set for true thread-local storage (not fiber-local)
      # - Control concern methods check this before yielding
      #
      # @see Core For run entry points
      # @see Completion For result building
      # @see ErrorHandling For error recovery
      # @see Planning For execute_planning_step_if_needed override
      # @see Repetition For check_and_handle_repetition override
      # @see Evaluation For execute_evaluation_if_needed override
      module Execution
        def self.included(base)
          base.include(Completion)
          base.include(ErrorHandling)
        end

        private

        def fiber_loop(task:, additional_prompting:, images:, memory: @memory)
          with_fiber_context { execute_fiber_loop(task, additional_prompting, images, memory:) }
        end

        def with_fiber_context
          Control::FiberControl.set_fiber_context(true)
          yield
        ensure
          Control::FiberControl.set_fiber_context(false)
        end

        def execute_fiber_loop(task, additional_prompting, images, memory:)
          prepare_task(task, additional_prompting:, images:)
          run_steps(task, RunContext.start, memory:)
        rescue StandardError => e
          finalize_error(e, @ctx, memory:)
        end

        def run_steps(task, ctx, memory:)
          @ctx = ctx
          execute_initial_planning_if_needed(task) { |u| ctx = ctx.add_tokens(u) }
          until ctx.exceeded?(@max_steps)
            step, ctx = execute_single_step(task, ctx, memory)
            result = check_step_completion(task, step, ctx, memory)
            return result if result

            ctx = (@ctx = after_step(task, step, ctx))
          end
          finalize(:max_steps_reached, nil, ctx, memory:)
        end

        def execute_single_step(task, ctx, memory)
          step, ctx = execute_step_with_monitoring(task, ctx, memory:)
          check_and_handle_repetition(memory.action_steps, memory:)
          Fiber.yield(step)
          [step, ctx]
        end

        def check_step_completion(task, step, ctx, memory)
          return finalize(:success, step.action_output, ctx, memory:) if step.is_final_answer
          return unless (r = execute_evaluation_if_needed(task, step, ctx.step_number))

          @ctx = ctx.add_tokens(r.token_usage) if r.token_usage
          finalize(:success, r.answer, ctx, memory:) if r.goal_achieved?
        end

        def after_step(task, step, ctx)
          execute_planning_step_if_needed(task, step, ctx.step_number) { |u| ctx = ctx.add_tokens(u) }
          ctx.advance
        end

        # No-op stubs for opt-in concerns
        def execute_planning_step_if_needed(_task, _step, _step_number); end
        def execute_initial_planning_if_needed(_task); end

        # No-op stub for repetition detection (opt-in via Repetition concern)
        # @param _steps [Array<ActionStep>] Recent action steps to check for repetition
        # @param memory [#add_system_message, nil] Optional memory for adding guidance messages
        def check_and_handle_repetition(_steps, memory: nil); end

        # No-op stub for evaluation (opt-in via Evaluation concern)
        def execute_evaluation_if_needed(_task, _step, _step_count) = nil

        def execute_step_with_monitoring(task, ctx, memory:)
          @logger.step_start(ctx.step_number)
          s = execute_instrumented_step(task, ctx, memory:).tap { |st| emit_step_event(st) }
          @logger.step_complete(ctx.step_number, duration: step_monitors["step_#{ctx.step_number}"].duration)
          record_observability(s, ctx)
          [s, ctx.add_tokens(s.token_usage)]
        end

        def execute_instrumented_step(task, ctx, memory:)
          r = nil
          monitor_step("step_#{ctx.step_number}") do
            r = Instrumentation.instrument("smolagents.agent.step", step_number: ctx.step_number,
                                                                    agent_class: self.class.name) do
              step(task, step_number: ctx.step_number).tap { |s| memory.add_step(s) }
            end
          end
          r
        end

        def record_observability(step, ctx)
          return unless (o = Types::ObservabilityContext.current)

          o.record_step(ctx.step_number)
          o.add_tokens(step.token_usage)
          step.tool_calls&.each { |tc| o.record_tool_call(tc.name) }
        end

        def emit_step_event(step)
          return unless emitting?

          emit_event(Events::StepCompleted.create(step_number: step.step_number, observations: step.observations,
                                                  outcome: step_outcome(step)))
        end

        def step_outcome(step)
          return :final_answer if step.is_final_answer

          (step.respond_to?(:error) && step.error ? :error : :success)
        end
      end
    end
  end
end
