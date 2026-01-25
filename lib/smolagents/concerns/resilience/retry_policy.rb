require_relative "retry_policy/config"
require_relative "retry_policy/backoff"
require_relative "retry_policy/classification"

module Smolagents
  module Concerns
    # Retry configuration for model reliability.
    #
    # Immutable configuration for retry behavior with exponential/linear backoff.
    # Intervals are for informational/callback purposes only - this module does NOT sleep.
    # The caller handles scheduling via event callbacks.
    #
    # @example Creating custom policy
    #   policy = RetryPolicy.new(
    #     max_attempts: 5,
    #     base_interval: 2.0,
    #     max_interval: 60.0,
    #     backoff: :exponential,
    #     retryable_errors: [Faraday::Error]
    #   )
    #
    # @example Using default policy
    #   policy = RetryPolicy.default
    #   #=> max_attempts: 3, base_interval: 1.0, backoff: :exponential
    #
    # @see RetryPolicyConfig For configuration presets
    # @see RetryPolicyBackoff For backoff calculation
    # @see RetryPolicyClassification For error classification
    RetryPolicy = Data.define(
      :max_attempts, :base_interval, :max_interval, :backoff, :jitter, :retryable_errors
    ) do
      # Get the default retry policy.
      # @return [RetryPolicy] Default configuration (3 attempts, exponential backoff)
      def self.default
        new(**RetryPolicyConfig::DEFAULTS, retryable_errors: RetryPolicyClassification::RETRIABLE_ERRORS)
      end

      # Get an aggressive retry policy for critical operations.
      # @return [RetryPolicy] More retries with shorter intervals
      def self.aggressive
        new(**RetryPolicyConfig::AGGRESSIVE, retryable_errors: RetryPolicyClassification::RETRIABLE_ERRORS)
      end

      # Get a conservative retry policy for expensive operations.
      # @return [RetryPolicy] Fewer retries with longer intervals
      def self.conservative
        new(**RetryPolicyConfig::CONSERVATIVE, retryable_errors: RetryPolicyClassification::RETRIABLE_ERRORS)
      end

      # Calculate the backoff multiplier based on the strategy.
      # @return [Float] Multiplier for the configured backoff strategy
      def multiplier = RetryPolicyBackoff.multiplier_for(backoff)

      # Calculate backoff interval for a given retry attempt with jitter.
      #
      # @param retry_num [Integer] Retry attempt number (0-indexed)
      # @return [Float] Backoff interval in seconds with jitter applied
      def backoff_for(retry_num)
        RetryPolicyBackoff.interval_for(
          attempt: retry_num,
          strategy: backoff,
          base: base_interval,
          max: max_interval,
          jitter:
        )
      end

      # Check if an error should trigger a retry.
      #
      # @param error [StandardError] The error to check
      # @return [Boolean] True if this error should trigger a retry
      def retriable?(error)
        return RetryPolicyClassification.retriable?(error) if retryable_errors.nil?

        retryable_errors.any? { |klass| error.is_a?(klass) }
      end
    end
  end
end
