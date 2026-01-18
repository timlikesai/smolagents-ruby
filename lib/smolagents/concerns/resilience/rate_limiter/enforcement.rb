module Smolagents
  module Concerns
    module RateLimiter
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
          raise RateLimitExceeded.new(retry_after: wait_time, tool_name: rate_limit_tool_name)
        end

        # Execute block with rate limit check, returning event-based result.
        #
        # @yield Block to execute if rate limit allows
        # @return [Array] [:success, result] or [:rate_limited, event]
        #
        # @example
        #   case with_rate_limit { api_call }
        #   in [:success, result] then handle_result(result)
        #   in [:rate_limited, event] then schedule_retry(event)
        #   end
        def with_rate_limit(original_request: nil)
          unless rate_limit_ok?
            event = rate_limit_event(original_request:)
            notify_rate_limited(event.retry_after)
            return [:rate_limited, event]
          end

          mark_request!
          [:success, yield]
        end
      end
    end
  end
end
