module Smolagents
  module Concerns
    # Event-driven retry logic for tool execution.
    #
    # Provides non-blocking retry logic that returns retry information
    # instead of sleeping. The caller controls how delays are handled
    # (event loops, schedulers, Fibers, or immediate execution for tests).
    #
    # @example Single attempt (event-driven)
    #   result = try_tool_call(policy:, attempt: 1) { api_call }
    #   case result
    #   in Types::RetryResult[status: :success, value:]
    #     return value
    #   in Types::RetryResult[status: :retry_needed, retry_info:]
    #     schedule_after(retry_info.backoff_seconds) { retry }
    #   end
    #
    # @example With delay handler (for synchronous contexts)
    #   with_tool_retry(policy:, on_delay: method(:sleep)) { api_call }
    #
    # @example For tests (no delay)
    #   with_tool_retry(policy:, on_delay: ->(_) {}) { api_call }
    #
    # @see RetryPolicy For backoff configuration
    # @see Types::RetryResult For return values
    module ToolRetry
      # Default retry policy for tool calls.
      #
      # More aggressive than model retries since tool calls are usually cheaper
      # and rate limits are common. Uses jitter to prevent thundering herd.
      #
      # @return [RetryPolicy] Default tool retry configuration
      def self.default_policy
        RetryPolicy.new(
          max_attempts: 3,
          base_interval: 2.0,
          max_interval: 30.0,
          backoff: :exponential,
          jitter: 0.5,
          retryable_errors: RetryPolicyClassification::RETRIABLE_ERRORS
        )
      end

      # Make a single tool call attempt, returning result or retry info.
      #
      # This is the core event-driven method. It never blocks. Returns
      # a RetryResult that indicates success, retry needed, or exhausted.
      #
      # @param policy [RetryPolicy] Retry configuration
      # @param attempt [Integer] Current attempt number (1-indexed)
      # @yield Block containing the tool call
      # @return [Types::RetryResult] Result of the attempt
      def try_tool_call(policy: ToolRetry.default_policy, attempt: 1)
        value = yield
        Types::RetryResult.success(value)
      rescue StandardError => e
        handle_tool_error(policy, attempt, e)
      end

      # Execute with retry, using provided delay handler.
      #
      # Wraps try_tool_call in a loop, delegating delay handling to the
      # caller-provided on_delay callback. The callback receives the
      # backoff duration and should block/schedule appropriately.
      #
      # @param policy [RetryPolicy] Retry configuration
      # @param on_delay [#call] Callback receiving backoff seconds
      # @yield Block containing the tool call
      # @return [Object] Result of the block
      # @raise [StandardError] Last error if all retries exhausted
      #
      # @example With sleep (blocking)
      #   with_tool_retry(on_delay: method(:sleep)) { http_call }
      #
      # @example With Fiber yield
      #   with_tool_retry(on_delay: ->(s) { Fiber.yield([:wait, s]) }) { call }
      def with_tool_retry(on_delay:, policy: ToolRetry.default_policy, &block)
        attempt = 1
        loop { attempt = process_retry_attempt(on_delay, policy, attempt, block) { |val| return val } }
      end

      def process_retry_attempt(on_delay, policy, attempt, block)
        case try_tool_call(policy:, attempt:, &block)
        in Types::RetryResult[status: :success, value:] then yield value
        in Types::RetryResult[status: :retry_needed, retry_info:]
          emit_retry_event(retry_info)
          on_delay.call(retry_info.backoff_seconds)
          attempt + 1
        in Types::RetryResult[status: :exhausted | :error, error:] then raise error
        end
      end

      private

      def handle_tool_error(policy, attempt, error)
        return Types::RetryResult.error(error) unless policy.retriable?(error)

        return Types::RetryResult.exhausted(error) if attempt >= policy.max_attempts

        backoff = calculate_backoff(policy, attempt, error)
        info = Types::RetryInfo.new(
          backoff_seconds: backoff,
          attempt:,
          max_attempts: policy.max_attempts,
          error:
        )
        Types::RetryResult.needs_retry(info)
      end

      def calculate_backoff(policy, attempt, error)
        # Use retry-after header if available (for rate limits)
        if error.respond_to?(:retry_after) && error.retry_after
          [error.retry_after, policy.max_interval].min
        else
          policy.backoff_for(attempt - 1)
        end
      end

      def emit_retry_event(retry_info)
        return unless respond_to?(:emit_event, true)

        emit_event(Events::ToolRetrying.create(
                     attempt: retry_info.attempt,
                     max_attempts: retry_info.max_attempts,
                     backoff_seconds: retry_info.backoff_seconds,
                     error_message: retry_info.error.message
                   ))
      rescue NameError
        # ToolRetrying event not defined - skip
      end
    end
  end
end
