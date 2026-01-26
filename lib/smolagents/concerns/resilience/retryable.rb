module Smolagents
  module Concerns
    # Retry with exponential backoff using RetryPolicy.
    #
    # Retries failed operations using a configurable RetryPolicy.
    # Uses the policy's backoff calculation and error classification.
    # Delegates to {BaseRetryHandler} for the core retry loop.
    #
    # @example Basic retry with default policy
    #   with_retry { api_call }
    #
    # @example Custom policy
    #   with_retry(policy: RetryPolicy.aggressive) { api_call }
    #
    # @example With specific errors and attempts
    #   policy = RetryPolicy.new(
    #     max_attempts: 5,
    #     retryable_errors: [Faraday::Error],
    #     base_interval: 1.0,
    #     max_interval: 30.0,
    #     backoff: :exponential,
    #     jitter: 0.5
    #   )
    #   with_retry(policy:) { api_call }
    #
    # @see Types::RetryPolicy For configuration options
    # @see BaseRetryHandler For the underlying retry implementation
    module Retryable
      # Retry a block using the given policy.
      #
      # @param policy [RetryPolicy] Retry configuration (default: RetryPolicy.default)
      # @yield Block to execute
      # @return [Object] Result of the block
      # @raise [StandardError] Last error if all retries fail
      def with_retry(policy: Types::RetryPolicy.default, &)
        # Use a method call for delay so tests can stub it
        delay_handler = ->(seconds) { retry_delay(seconds) }
        handler = BaseRetryHandler.new(policy:, on_delay: delay_handler)
        handler.execute(&)
      end

      private

      # Sleep before retry. Override or stub in tests to skip delays.
      # @param seconds [Float] Duration to sleep
      def retry_delay(seconds)
        sleep(seconds) # rubocop:disable Smolagents/NoSleep -- retry backoff
      end
    end
  end
end
