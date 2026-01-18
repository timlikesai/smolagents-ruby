module Smolagents
  module Tools
    class ManagedAgentTool < Tool
      # Result handling and event emission for managed agent execution.
      module ResultHandling
        private

        def handle_error(err, task, event)
          emit_error(err, context: { agent_name: @agent_name, task: }, recoverable: true)
          emit_completion(event&.id, :error, error: err.message)
          "Agent '#{@agent_name}' error: #{err.message}"
        end

        def handle_result(result, launch_id)
          return success_result(result, launch_id) if result.success?

          emit_completion(launch_id, :failure, result:, error: result.state.to_s)
          "Agent '#{@agent_name}' failed: #{result.state}"
        end

        def success_result(result, launch_id)
          emit_completion(launch_id, :success, result:, output: result.output.to_s)
          result.output.to_s
        end

        def emit_completion(launch_id, outcome, result: nil, output: nil, error: nil)
          record_to_observability(result, outcome)
          emit_event(Events::SubAgentCompleted.create(
                       launch_id:, agent_name: @agent_name, outcome:, output:, error:,
                       token_usage: result&.token_usage, step_count: result&.step_count,
                       duration: result&.duration
                     ))
        end

        def record_to_observability(result, outcome)
          return unless (obs_ctx = Types::ObservabilityContext.current) && result

          obs_ctx.record_sub_agent(
            agent_name: @agent_name,
            token_usage: result.token_usage,
            step_count: result.step_count,
            duration: result.duration,
            outcome:
          )
        end
      end
    end
  end
end
