module Smolagents
  module Concerns
    # Unified retry handling with configurable delay strategies.
    #
    # Provides a common retry loop that all retry concerns delegate to.
    # The caller controls delay handling via a strategy callback, allowing:
    # - Blocking sleep (for simple synchronous use)
    # - Non-blocking callbacks (for event-driven/Fiber use)
    # - No-op (for tests)
    #
    # @example Blocking retry (default)
    #   handler = BaseRetryHandler.new(policy:)
    #   handler.execute { api_call }
    #
    # @example Non-blocking with callback
    #   handler = BaseRetryHandler.new(policy:, on_delay: ->(s) { schedule_after(s) })
    #   handler.execute { api_call }
    #
    # @example With event emission
    #   handler = BaseRetryHandler.new(policy:, on_retry: method(:emit_retry_event))
    #   handler.execute { api_call }
    #
    # @see Types::RetryPolicy For backoff configuration
    class BaseRetryHandler
      # Default delay handler: blocking sleep.
      BLOCKING_DELAY = ->(seconds) { sleep(seconds) } # rubocop:disable Smolagents/NoSleep -- retry backoff

      # No-op delay handler for tests.
      NOOP_DELAY = ->(_) {}

      # @return [Types::RetryPolicy] Policy controlling retry behavior
      attr_reader :policy

      # @return [#call] Callback for handling delays between retries
      attr_reader :on_delay

      # @return [#call, nil] Optional callback for retry events
      attr_reader :on_retry

      # @return [#call, nil] Optional callback for error classification
      attr_reader :error_classifier

      # Create a new retry handler.
      #
      # @param policy [Types::RetryPolicy] Retry configuration
      # @param on_delay [#call] Delay handler (default: blocking sleep)
      # @param on_retry [#call, nil] Called before each retry with attempt info
      # @param error_classifier [#call, nil] Custom error classifier (default: policy.retriable?)
      def initialize(policy: Types::RetryPolicy.default, on_delay: BLOCKING_DELAY,
                     on_retry: nil, error_classifier: nil)
        @policy = policy
        @on_delay = on_delay
        @on_retry = on_retry
        @error_classifier = error_classifier
      end

      # Execute block with retry logic.
      #
      # @yield Block to execute (may be retried)
      # @return [Object] Result of successful execution
      # @raise [StandardError] Last error if all retries exhausted
      def execute
        attempt = 0
        last_error = nil
        loop { last_error = try_attempt(attempt += 1) { return yield } }
        raise last_error
      end

      private

      def try_attempt(attempt)
        yield
      rescue StandardError => e
        raise e unless should_retry?(e, attempt)

        e
      end

      public

      # Make a single attempt, returning structured result.
      #
      # Non-blocking variant that returns result info instead of blocking.
      # Useful for event-driven or Fiber-based retry scheduling.
      #
      # @param attempt [Integer] Current attempt number (1-indexed)
      # @yield Block to execute
      # @return [Hash] Result with :status (:success, :retry_needed, :exhausted, :error)
      def try_once(attempt: 1)
        value = yield
        { status: :success, value: }
      rescue StandardError => e
        classify_attempt_result(e, attempt)
      end

      private

      def should_retry?(error, attempt)
        return false unless retriable?(error)
        return false unless policy.attempts_remaining?(attempt)

        backoff = calculate_backoff(attempt, error)
        notify_retry(attempt, backoff, error)
        on_delay.call(backoff)
        true
      end

      def classify_attempt_result(error, attempt)
        return { status: :error, error: } unless retriable?(error)
        return { status: :exhausted, error: } if attempt >= policy.max_attempts

        backoff = calculate_backoff(attempt, error)
        {
          status: :retry_needed,
          backoff_seconds: backoff,
          attempt:,
          max_attempts: policy.max_attempts,
          error:
        }
      end

      def retriable?(error)
        if error_classifier
          error_classifier.call(error)
        else
          policy.retriable?(error)
        end
      end

      def calculate_backoff(attempt, error)
        # Use retry-after header if available (for rate limits)
        if error.respond_to?(:retry_after) && error.retry_after
          [error.retry_after, policy.max_interval].min
        else
          policy.backoff_for(attempt - 1)
        end
      end

      def notify_retry(attempt, backoff, error)
        return unless on_retry

        on_retry.call(
          attempt:,
          max_attempts: policy.max_attempts,
          backoff_seconds: backoff,
          error:
        )
      end
    end
  end
end
