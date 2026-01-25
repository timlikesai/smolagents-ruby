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

        # Sync mode fiber consumption for automatic request handling.
        module SyncHandler
          def self.provided_methods
            { consume_fiber: "Consume fiber in sync mode, auto-handling control requests" }
          end

          private

          # Consume a fiber, automatically handling control requests.
          def consume_fiber(fiber)
            result = fiber.resume
            loop { result = process_fiber_result(fiber, result) { |final| return final } }
          end

          def process_fiber_result(fiber, result, &)
            case result
            in Types::ActionStep then fiber.resume
            in Types::ControlRequests::Request => req then fiber.resume(handle_sync_control_request(req))
            in Executors::BatchYield => batch then process_batch(fiber, batch, &)
            in Types::RunResult => final then yield final
            end
          end

          def process_batch(fiber, batch)
            batch.futures.each(&:_execute!)
            fiber.resume
          rescue Smolagents::FinalAnswerException => e
            # final_answer was called - return as RunResult
            yield build_final_result(e.value)
          end

          def build_final_result(value)
            Types::RunResult.success(output: value, steps: [])
          end

          def handle_sync_control_request(req)
            case req.sync_behavior
            in :default then sync_default_response(req)
            in :approve then Types::ControlRequests::Response.approve(request_id: req.id)
            in :skip then Types::ControlRequests::Response.respond(request_id: req.id, value: nil)
            else raise_sync_error(req)
            end
          end

          def sync_default_response(req)
            value = req.respond_to?(:default_value) ? req.default_value : nil
            value ? Types::ControlRequests::Response.respond(request_id: req.id, value:) : raise_sync_error(req)
          end

          def raise_sync_error(req)
            raise ControlFlowError.new("Control request #{req.class.name} cannot be handled in sync mode",
                                       request_type: req.class.name.split("::").last.to_sym, context: req.to_h)
          end
        end
      end
    end
  end
end
