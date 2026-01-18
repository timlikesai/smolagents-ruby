require_relative "rate_limiter/errors"
require_relative "rate_limiter/configuration"
require_relative "rate_limiter/tracking"
require_relative "rate_limiter/callbacks"
require_relative "rate_limiter/events"
require_relative "rate_limiter/enforcement"
require_relative "rate_limiter/strategies"

module Smolagents
  module Concerns
    # Event-driven rate limiting for tools that call external APIs.
    #
    # Uses a non-blocking pattern: checks if a request is allowed, and if not,
    # raises RateLimitExceeded with retry_after information. Callers can handle
    # this via callbacks, request queues, or other event-driven mechanisms.
    #
    # @example Declarative rate limiting with DSL
    #   class MyApiTool < Tool
    #     include Concerns::RateLimiter
    #
    #     rate_limit 1.0  # Allow 1 request per second
    #
    #     def execute(query:)
    #       enforce_rate_limit!  # Raises RateLimitExceeded if too soon
    #       # ... make API call
    #     end
    #   end
    #
    # @example Handling rate limits with callbacks
    #   tool.on_rate_limited do |retry_after|
    #     scheduler.schedule_after(retry_after) { tool.call(query:) }
    #   end
    #
    # @example Check before calling (non-raising)
    #   if tool.rate_limit_ok?
    #     tool.call(query:)
    #   else
    #     queue.push(-> { tool.call(query:) }, delay: tool.retry_after)
    #   end
    #
    # @see SearchTool Which automatically configures rate limiting
    # @see RequestQueue For queuing rate-limited requests
    module RateLimiter
      def self.included(base)
        base.include(Configuration)
        base.include(Tracking)
        base.include(Callbacks)
        base.include(Events)
        base.include(Enforcement)
      end
    end
  end
end
