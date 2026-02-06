module Smolagents
  module Types
    # Immutable retry policy configuration for model reliability.
    #
    # Defines retry behavior with configurable backoff strategies. Intervals
    # are for informational/callback purposes only - this type does NOT sleep.
    # The caller handles scheduling via event callbacks.
    #
    # @example Creating a custom policy
    #   policy = RetryPolicy.new(
    #     max_attempts: 5,
    #     base_interval: 2.0,
    #     max_interval: 60.0,
    #     backoff: :exponential,
    #     jitter: 0.5,
    #     retryable_errors: [Faraday::Error]
    #   )
    #
    # @example Using factory methods
    #   RetryPolicy.default      # 3 attempts, exponential
    #   RetryPolicy.aggressive   # 5 attempts, faster
    #   RetryPolicy.conservative # 2 attempts, slower
    #
    # @example Calculating backoff
    #   policy = RetryPolicy.default
    #   policy.backoff_for(0)  # => ~1.0 seconds
    #   policy.backoff_for(1)  # => ~2.0 seconds
    #   policy.backoff_for(2)  # => ~4.0 seconds
    RetryPolicy = Data.define(
      :max_attempts, :base_interval, :max_interval, :backoff, :jitter, :retryable_errors
    ) do
      include TypeSupport::Deconstructable

      # Configuration presets (scoped to avoid collisions with other types)
      DEFAULT_CONFIG = {
        max_attempts: 3,
        base_interval: 1.0,
        max_interval: 30.0,
        backoff: :exponential,
        jitter: 0.5
      }.freeze

      AGGRESSIVE_CONFIG = {
        max_attempts: 5,
        base_interval: 0.5,
        max_interval: 15.0,
        backoff: :exponential,
        jitter: 0.3
      }.freeze

      CONSERVATIVE_CONFIG = {
        max_attempts: 2,
        base_interval: 2.0,
        max_interval: 60.0,
        backoff: :exponential,
        jitter: 1.0
      }.freeze

      # Backoff strategy multipliers
      STRATEGY_MULTIPLIERS = {
        exponential: 2.0,
        linear: 1.5,
        constant: 1.0
      }.freeze

      # HTTP status codes that are transient and worth retrying
      RETRIABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504].freeze

      # Default retriable error classes (resolved lazily to avoid load order issues)
      DEFAULT_RETRIABLE_ERRORS = lambda {
        [
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          Faraday::ServerError, # 5xx errors - check status code for granularity
          RateLimitError,
          ServiceUnavailableError
        ]
      }

      # Get the default retry policy.
      # @return [RetryPolicy] Default configuration (3 attempts, exponential backoff)
      def self.default
        new(**DEFAULT_CONFIG, retryable_errors: DEFAULT_RETRIABLE_ERRORS.call)
      end

      # Get an aggressive retry policy for critical operations.
      # @return [RetryPolicy] More retries with shorter intervals
      def self.aggressive
        new(**AGGRESSIVE_CONFIG, retryable_errors: DEFAULT_RETRIABLE_ERRORS.call)
      end

      # Get a conservative retry policy for expensive operations.
      # @return [RetryPolicy] Fewer retries with longer intervals
      def self.conservative
        new(**CONSERVATIVE_CONFIG, retryable_errors: DEFAULT_RETRIABLE_ERRORS.call)
      end

      # Calculate the backoff multiplier based on the strategy.
      # @return [Float] Multiplier for the configured backoff strategy
      def multiplier = STRATEGY_MULTIPLIERS.fetch(backoff, 1.0)

      # Calculate backoff interval for a given retry attempt with jitter.
      #
      # @param retry_num [Integer] Retry attempt number (0-indexed)
      # @return [Float] Backoff interval in seconds with jitter applied
      def backoff_for(retry_num)
        raw = base_interval * (multiplier**retry_num)
        capped = [raw, max_interval].min
        jitter ? add_jitter(capped) : capped
      end

      # Check if an error should trigger a retry.
      #
      # Checks both error class and HTTP status code (for Faraday errors).
      # Status codes 408, 429, 500, 502, 503, 504 are considered retriable.
      #
      # @param error [StandardError] The error to check
      # @return [Boolean] True if this error should trigger a retry
      def retriable?(error)
        # Check HTTP status code for Faraday errors
        if error.respond_to?(:response_status) && error.response_status
          return RETRIABLE_STATUS_CODES.include?(error.response_status)
        end

        # Fall back to class-based check
        errors_to_check = retryable_errors || DEFAULT_RETRIABLE_ERRORS.call
        errors_to_check.any? { |klass| error.is_a?(klass) }
      end

      # Whether this policy has remaining attempts.
      #
      # @param current_attempt [Integer] Current attempt number (1-indexed)
      # @return [Boolean] True if more attempts are available
      def attempts_remaining?(current_attempt) = current_attempt < max_attempts

      private

      def add_jitter(interval) = interval + rand(0.0..jitter)
    end
  end
end
