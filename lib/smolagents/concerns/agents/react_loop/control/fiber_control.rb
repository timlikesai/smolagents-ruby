module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Fiber context management for bidirectional control flow.
        module FiberControl
          def self.provided_methods
            {
              yield_control: "Yield to fiber consumer with a control request",
              ensure_fiber_context!: "Raise if not in fiber context",
              fiber_context?: "Check if currently in fiber context"
            }
          end

          # Thread variable key for fiber context detection.
          FIBER_CONTEXT_KEY = :smolagents_fiber_context

          # Check if currently in fiber context (public API).
          # Uses thread_variable_get for true thread-local storage (not fiber-local).
          def fiber_context? = Thread.current.thread_variable_get(FIBER_CONTEXT_KEY) == true

          # Set fiber context flag. Must be called when entering fiber-based execution.
          # rubocop:disable Naming/AccessorMethodName -- not a typical setter
          def self.set_fiber_context(value)
            Thread.current.thread_variable_set(FIBER_CONTEXT_KEY, value)
          end
          # rubocop:enable Naming/AccessorMethodName

          private

          # Yield control to the fiber consumer with a request. Emits events before/after.
          def yield_control(request)
            emit(Events::ControlYielded.create(
                   request_type: request_type_sym(request), request_id: request.id, prompt: extract_prompt(request)
                 ))
            response = Fiber.yield(request)
            emit(Events::ControlResumed.create(
                   request_id: request.id, approved: response.approved?, value: response.value&.to_s&.slice(0, 100)
                 ))
            response
          end

          def ensure_fiber_context!
            return if fiber_context?

            raise Errors::ControlFlowError, "Control requests require Fiber context. Use run_fiber instead of run."
          end

          def request_type_sym(req) = req.class.name.split("::").last.downcase.to_sym

          def extract_prompt(req)
            %i[prompt query description].find { |m| req.respond_to?(m) }&.then { |m| req.send(m) } || req.to_h.to_s
          end
        end
      end
    end
  end
end
