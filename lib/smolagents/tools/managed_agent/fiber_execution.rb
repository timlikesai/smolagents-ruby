module Smolagents
  module Tools
    class ManagedAgentTool < Tool
      # Fiber-based execution for managed agents.
      #
      # Enables cooperative multitasking when running within a fiber context,
      # allowing control requests to bubble up to parent agents.
      module FiberExecution
        private

        def fiber_context? = Thread.current[:smolagents_fiber_context] == true

        def execute_sync(task, _event) = @agent.run(task, reset: true)

        def execute_fiber(task, event)
          sub_fiber = @agent.run_fiber(task, reset: true)
          pending = nil
          loop do
            case (result = sub_fiber.resume(pending))
            when Types::ControlRequests::Request then pending = bubble_request(result)
            when Types::ActionStep then emit_progress(event, result)
            when Types::RunResult then return result
            end
          end
        end

        def bubble_request(req)
          wrapped = Types::ControlRequests::SubAgentQuery.create(
            agent_name: @agent_name,
            query: req.respond_to?(:prompt) ? req.prompt : req.query,
            context: { original: req.to_h, original_id: req.id },
            options: req.respond_to?(:options) ? req.options : nil
          )
          parent_response = Fiber.yield(wrapped)
          Types::ControlRequests::Response.respond(request_id: req.id, value: parent_response.value)
        end

        def emit_progress(event, step)
          msg = step.observations&.to_s&.slice(0, 100)
          emit_event(Events::SubAgentProgress.create(
                       launch_id: event&.id,
                       agent_name: @agent_name,
                       step_number: step.step_number,
                       message: msg
                     ))
        end
      end
    end
  end
end
