module Smolagents
  module Concerns
    module ReActLoop
      module Execution
        # Step monitoring, instrumentation, and event emission.
        #
        # Handles logging, telemetry, observability recording, and event emission
        # for step execution. Separated from core loop logic for clarity.
        #
        # @see Loop For core step iteration
        module Monitoring
          private

          # Execute step with logging and monitoring.
          # @param task [String] Task description
          # @param ctx [RunContext] Current context
          # @param memory [AgentMemory] History
          # @return [Array] [ActionStep, updated RunContext]
          def execute_step_with_monitoring(task, ctx, memory:)
            @logger.step_start(ctx.step_number)
            s = execute_instrumented_step(task, ctx, memory:).tap { |st| emit_step_event(st) }
            @logger.step_complete(ctx.step_number, duration: step_monitors["step_#{ctx.step_number}"].duration)
            record_observability(s, ctx)
            [s, ctx.add_tokens(s.token_usage)]
          end

          # Execute step with instrumentation and memory recording.
          # @param task [String] Task description
          # @param ctx [RunContext] Current context
          # @param memory [AgentMemory] Step history
          # @return [ActionStep] Executed step
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

          # Record step execution to observability context.
          # @param step [ActionStep] Executed step
          # @param ctx [RunContext] Current context
          # @return [void]
          def record_observability(step, ctx)
            return unless (o = Types::ObservabilityContext.current)

            o.record_step(ctx.step_number)
            o.add_tokens(step.token_usage)
            step.tool_calls&.each { |tc| o.record_tool_call(tc.name) }
          end

          # Emit step completion event with outcome.
          # @param step [ActionStep] Completed step
          # @return [void]
          def emit_step_event(step)
            return unless emitting?

            emit_tool_call_events
            emit_event(Events::StepCompleted.create(step_number: step.step_number, observations: step.observations,
                                                    outcome: step_outcome(step)))
          end

          # Emit ToolCallCompleted events for all tracked tool calls.
          # @return [void]
          def emit_tool_call_events
            return unless @executor.respond_to?(:tool_calls)

            @executor.tool_calls.each do |call|
              emit_event(Events::ToolCallCompleted.create(
                           request_id: SecureRandom.uuid,
                           tool_name: call.tool_name,
                           result: call.result,
                           observation: call.result.to_s,
                           is_final: call.tool_name == "final_answer"
                         ))
            end
          end

          # Determine step outcome (final_answer, error, or success).
          # @param step [ActionStep] Step to evaluate
          # @return [Symbol] :final_answer, :error, or :success
          def step_outcome(step)
            return :final_answer if step.is_final_answer

            (step.respond_to?(:error) && step.error ? :error : :success)
          end
        end
      end
    end
  end
end
