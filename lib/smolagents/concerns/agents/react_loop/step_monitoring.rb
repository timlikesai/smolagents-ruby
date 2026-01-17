module Smolagents
  module Concerns
    module ReActLoop
      # Step execution with monitoring and instrumentation.
      module StepMonitoring
        private

        def execute_step_with_monitoring(task, context)
          @logger.step_start(context.step_number)
          current_step = monitor_and_instrument_step(task, context)
          @logger.step_complete(context.step_number, duration: step_monitors["step_#{context.step_number}"].duration)
          record_step_to_observability(current_step, context)
          [current_step, context.add_tokens(current_step.token_usage)]
        end

        def record_step_to_observability(step, context)
          obs_ctx = Types::ObservabilityContext.current
          return unless obs_ctx

          obs_ctx.record_step(context.step_number)
          obs_ctx.add_tokens(step.token_usage)
          step.tool_calls&.each { |tc| obs_ctx.record_tool_call(tc.name) }
        end

        def monitor_and_instrument_step(task, context)
          current_step = execute_instrumented_step(task, context)
          emit_step_completed_event(current_step)
          current_step
        end

        def execute_instrumented_step(task, context)
          result = nil
          monitor_step("step_#{context.step_number}") do
            result = instrument_step(task, context)
          end
          result
        end

        def instrument_step(task, context)
          Instrumentation.instrument(
            "smolagents.agent.step",
            step_number: context.step_number,
            agent_class: self.class.name
          ) do
            step(task, step_number: context.step_number).tap { |s| @memory.add_step(s) }
          end
        end
      end
    end
  end
end
