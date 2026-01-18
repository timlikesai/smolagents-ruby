module Smolagents
  module Concerns
    module ReActLoop
      module Control
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

          def process_fiber_result(fiber, result)
            case result
            in Types::ActionStep then fiber.resume
            in Types::ControlRequests::Request => req then fiber.resume(handle_sync_control_request(req))
            in Types::RunResult => final then yield final
            end
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
