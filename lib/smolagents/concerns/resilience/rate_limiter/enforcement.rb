module Smolagents
  module Concerns
    module RateLimiter
      # Raised when rate limit would be exceeded.
      # Contains retry_after to enable event-driven scheduling.
      class RateLimitExceeded < Errors::AgentError
        attr_reader :retry_after, :tool_name

        def initialize(retry_after:, tool_name: nil)
          @retry_after = retry_after
          @tool_name = tool_name
          super("Rate limit exceeded. Retry after #{retry_after.round(3)}s")
        end
      end

      # Rate limit enforcement methods.
      module Enforcement
        # Enforce rate limit (non-blocking).
        # Raises RateLimitExceeded if called too soon.
        #
        # @raise [RateLimitExceeded] If rate limit would be exceeded
        # @return [void]
        def enforce_rate_limit!
          return mark_request! unless @rate_limit && (wait_time = time_until_allowed).positive?

          notify_rate_limited(wait_time)
          emit_rate_limit_violated
          raise RateLimitExceeded.new(retry_after: wait_time, tool_name: rate_limit_tool_name)
        end

        # Execute block with rate limit check, returning event-based result.
        #
        # @yield Block to execute if rate limit allows
        # @return [Array] [:success, result] or [:rate_limited, event]
        def with_rate_limit(original_request: nil)
          unless rate_limit_ok?
            event = rate_limit_event(original_request:)
            notify_rate_limited(event.retry_after)
            emit_rate_limit_violated
            return [:rate_limited, event]
          end

          mark_request!
          [:success, yield]
        end
      end
    end
  end
end
