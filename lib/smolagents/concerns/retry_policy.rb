module Smolagents
  module Concerns
    # Retry configuration for model reliability.
    #
    # Immutable configuration for retry behavior with exponential/linear backoff.
    # Intervals are for informational/callback purposes only - this module does NOT sleep.
    # The caller handles scheduling via event callbacks.
    #
    # @!attribute [r] max_attempts
    #   @return [Integer] Maximum number of retry attempts
    # @!attribute [r] base_interval
    #   @return [Float] Initial backoff interval in seconds
    # @!attribute [r] max_interval
    #   @return [Float] Maximum backoff interval in seconds
    # @!attribute [r] backoff
    #   @return [Symbol] Backoff strategy (:exponential, :linear, or :constant)
    # @!attribute [r] retryable_errors
    #   @return [Array<Class>] Exception classes that trigger retries
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
    #   # => max_attempts: 3, base_interval: 1.0, backoff: :exponential
    RetryPolicy = Data.define(:max_attempts, :base_interval, :max_interval, :backoff, :retryable_errors) do
      # Get the default retry policy (3 attempts, 1s base interval, exponential backoff).
      #
      # @return [RetryPolicy] Default retry configuration
      def self.default
        new(
          max_attempts: 3,
          base_interval: 1.0,
          max_interval: 30.0,
          backoff: :exponential,
          retryable_errors: [Faraday::Error, Faraday::TimeoutError]
        )
      end

      # Calculate the backoff multiplier based on the strategy.
      #
      # @return [Float] Multiplier for exponential (2.0), linear (1.5), or constant (1.0) backoff
      #
      # @example Exponential growth
      #   policy = RetryPolicy.new(..., backoff: :exponential)
      #   policy.multiplier  # => 2.0
      #   # Intervals: 1s, 2s, 4s, 8s, 16s, 30s (capped)
      def multiplier
        case backoff
        when :exponential then 2.0
        when :linear then 1.5
        else 1.0
        end
      end

      # Calculate backoff interval for a given retry attempt.
      #
      # @param retry_num [Integer] Retry attempt number (0-indexed)
      # @return [Float] Backoff interval in seconds
      def backoff_for(retry_num)
        interval = base_interval * (multiplier**retry_num)
        [interval, max_interval].min
      end
    end
  end
end
