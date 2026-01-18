module Smolagents
  module Concerns
    module RateLimiter
      # Event creation for rate limit integration.
      module Events
        def self.included(base)
          base.include(Smolagents::Events::Emitter)
        end

        # Create a rate limit event for the Events system.
        #
        # @param original_request [Object, nil] The original request to retry
        # @return [Events::RateLimitHit] Event for scheduling
        #
        # @example
        #   unless tool.rate_limit_ok?
        #     event = tool.rate_limit_event(original_request: request)
        #     event_queue.push(event, priority: :scheduled)
        #   end
        def rate_limit_event(original_request: nil)
          Smolagents::Events::RateLimitHit.create(
            tool_name: rate_limit_tool_name,
            retry_after:,
            original_request:
          )
        end

        # Emit a RateLimitViolated event.
        #
        # @return [Events::RateLimitViolated] The emitted event
        def emit_rate_limit_violated
          emit_event(Smolagents::Events::RateLimitViolated.create(
                       tool_name: rate_limit_tool_name,
                       retry_after:,
                       request_count:,
                       limit_interval:
                     ))
        end
      end
    end
  end
end
