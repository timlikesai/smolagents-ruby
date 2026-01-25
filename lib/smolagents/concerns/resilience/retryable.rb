module Smolagents
  module Concerns
    # Retry with exponential backoff.
    #
    # Retries failed operations with configurable backoff strategy.
    # Defaults to exponential backoff with jitter to prevent thundering herd.
    #
    # @example Basic retry with defaults (exponential backoff)
    #   with_retry(on: [Faraday::Error], tries: 3) do
    #     api_call
    #   end
    #
    # @example Immediate retry (no backoff)
    #   with_retry(on: [Faraday::Error], tries: 3, backoff: false) do
    #     api_call
    #   end
    #
    module Retryable
      # Default backoff configuration
      DEFAULT_BACKOFF = {
        strategy: :exponential,
        base: 0.5,      # Start with 0.5s
        max: 30.0,      # Cap at 30s
        jitter: 0.25    # Add up to 0.25s randomness
      }.freeze

      # Retry a block with exponential backoff on specified errors.
      #
      # @param on [Array<Class>] Error classes to retry on
      # @param tries [Integer] Maximum attempts (default: 3)
      # @param backoff [Hash, false] Backoff config or false to disable
      # @yield Block to execute
      # @return [Object] Result of the block
      # @raise [StandardError] Last error if all retries fail
      def with_retry(on:, tries: 3, backoff: DEFAULT_BACKOFF)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue *on => e
          raise e if attempt >= tries

          sleep_before_retry(attempt, backoff) if backoff
          retry
        end
      end

      private

      def sleep_before_retry(attempt, backoff)
        interval = RetryPolicyBackoff.interval_for(
          attempt:,
          strategy: backoff[:strategy],
          base: backoff[:base],
          max: backoff[:max],
          jitter: backoff[:jitter]
        )
        sleep(interval) # rubocop:disable Smolagents/NoSleep -- retry backoff prevents thundering herd on server errors
      end
    end
  end
end
