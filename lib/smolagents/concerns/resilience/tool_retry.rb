module Smolagents
  module Concerns
    # Event-driven retry logic for tool execution.
    #
    # Provides non-blocking retry logic that returns retry information
    # instead of sleeping. The caller controls how delays are handled
    # (event loops, schedulers, Fibers, or immediate execution for tests).
    # Delegates to {BaseRetryHandler} for core retry logic.
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
    # @see BaseRetryHandler For the underlying retry implementation
    module ToolRetry
      include Events::Emitter

      # Default retry policy for tool calls.
      #
      # Uses the standard RetryPolicy.default which is suitable for most tool calls.
      # Customize with RetryPolicy.aggressive for critical operations or
      # RetryPolicy.conservative for expensive ones.
      #
      # @return [RetryPolicy] Default tool retry configuration
      def self.default_policy
        Types::RetryPolicy.default
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
      def try_tool_call(policy: ToolRetry.default_policy, attempt: 1, &)
        handler = build_handler(policy)
        result = handler.try_once(attempt:, &)
        convert_to_retry_result(result)
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
      def with_tool_retry(on_delay:, policy: ToolRetry.default_policy, &)
        handler = build_handler(policy, on_delay:)
        handler.execute(&)
      end

      private

      def build_handler(policy, on_delay: BaseRetryHandler::NOOP_DELAY)
        BaseRetryHandler.new(
          policy:,
          on_delay:,
          on_retry: method(:handle_retry_event)
        )
      end

      def handle_retry_event(attempt:, max_attempts:, backoff_seconds:, error:)
        return unless defined?(Events::ToolRetrying)

        emit(Events::ToolRetrying.create(
               attempt:,
               max_attempts:,
               backoff_seconds:,
               error_message: error.message
             ))
      end

      def convert_to_retry_result(result)
        case result[:status]
        when :success   then Types::RetryResult.success(result[:value])
        when :exhausted then Types::RetryResult.exhausted(result[:error])
        when :error     then Types::RetryResult.error(result[:error])
        when :retry_needed then Types::RetryResult.needs_retry(build_retry_info(result))
        end
      end

      def build_retry_info(result)
        Types::RetryInfo.new(
          backoff_seconds: result[:backoff_seconds],
          attempt: result[:attempt],
          max_attempts: result[:max_attempts],
          error: result[:error]
        )
      end
    end
  end
end
