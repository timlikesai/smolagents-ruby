module Smolagents
  module Concerns
    module ReActLoop
      # Fiber consumption for sync and streaming execution.
      #
      # Provides methods to consume a Fiber in different modes:
      # - Sync: consume_fiber runs to completion, auto-approving control requests
      # - Stream: drain_fiber_to_enumerator yields steps as an Enumerator
      #
      # @see Core For the composed entry point
      # @see Control For overriding consume_fiber with custom handling
      module FiberConsumption
        private

        def run_sync(task, images:, additional_prompting:)
          consume_fiber(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def run_stream(task:, images: nil, additional_prompting: nil)
          drain_fiber_to_enumerator(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def drain_fiber_to_enumerator(fiber)
          Enumerator.new do |y|
            loop do
              case fiber.resume
              in Types::ActionStep => s then y << s
              in Types::ControlRequests::Request => req then fiber.resume(auto_approve(req))
              in RunResult then break
              end
            end
          end
        end

        def auto_approve(req) = Types::ControlRequests::Response.approve(request_id: req.id)

        # Default consume_fiber for sync execution (overridden by Control concern).
        # Auto-approves all control requests.
        def consume_fiber(fiber)
          loop do
            case fiber.resume
            in Types::ActionStep then next
            in Types::ControlRequests::Request => req then fiber.resume(auto_approve(req))
            in Types::RunResult => final then return final
            end
          end
        end
      end
    end
  end
end
