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
    # Error categories for retry classification.
    # Retriable errors are transient and worth retrying.
    # Non-retriable errors indicate permanent failures.
    #
    # @example Checking if an error is retriable
    #   RetryPolicy.retriable?(Faraday::TimeoutError.new)  # => true
    #   RetryPolicy.retriable?(AuthenticationError.new)    # => false
    module ErrorClassification
      # Errors that are transient and worth retrying
      RETRIABLE_ERRORS = [
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        RateLimitError,
        ServiceUnavailableError
      ].freeze

      # Errors that indicate permanent failures - don't retry
      NON_RETRIABLE_ERRORS = [
        Faraday::ClientError,        # 4xx errors (except rate limit)
        AgentConfigurationError,
        PromptInjectionError,
        MCPConnectionError
      ].freeze

      # HTTP status codes that are retriable
      RETRIABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504].freeze

      # Checks if an error is retriable based on classification.
      #
      # @param error [StandardError] The error to check
      # @return [Boolean] True if the error is transient and worth retrying
      def self.retriable?(error)
        return true if RETRIABLE_ERRORS.any? { |klass| error.is_a?(klass) }
        return false if NON_RETRIABLE_ERRORS.any? { |klass| error.is_a?(klass) }

        # Check HTTP status code if available
        if error.respond_to?(:response) && error.response.respond_to?(:status)
          return RETRIABLE_STATUS_CODES.include?(error.response.status)
        end

        # Check status_code attribute (our ApiError types)
        if error.respond_to?(:status_code) && error.status_code
          return RETRIABLE_STATUS_CODES.include?(error.status_code)
        end

        # Default: don't retry unknown errors
        false
      end
    end

    RetryPolicy = Data.define(:max_attempts, :base_interval, :max_interval, :backoff, :jitter, :retryable_errors) do
      # Get the default retry policy (3 attempts, 1s base interval, exponential backoff with jitter).
      #
      # @return [RetryPolicy] Default retry configuration
      def self.default
        new(
          max_attempts: 3,
          base_interval: 1.0,
          max_interval: 30.0,
          backoff: :exponential,
          jitter: 0.5,
          retryable_errors: ErrorClassification::RETRIABLE_ERRORS
        )
      end

      # Get an aggressive retry policy for critical operations.
      #
      # @return [RetryPolicy] More retries with shorter intervals
      def self.aggressive
        new(
          max_attempts: 5,
          base_interval: 0.5,
          max_interval: 15.0,
          backoff: :exponential,
          jitter: 0.3,
          retryable_errors: ErrorClassification::RETRIABLE_ERRORS
        )
      end

      # Get a conservative retry policy for expensive operations.
      #
      # @return [RetryPolicy] Fewer retries with longer intervals
      def self.conservative
        new(
          max_attempts: 2,
          base_interval: 2.0,
          max_interval: 60.0,
          backoff: :exponential,
          jitter: 1.0,
          retryable_errors: ErrorClassification::RETRIABLE_ERRORS
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

      # Calculate backoff interval for a given retry attempt with jitter.
      #
      # Jitter adds randomness to prevent thundering herd problems when
      # multiple clients retry simultaneously after a service recovery.
      #
      # @param retry_num [Integer] Retry attempt number (0-indexed)
      # @return [Float] Backoff interval in seconds with jitter applied
      #
      # @example With jitter
      #   policy = RetryPolicy.default
      #   policy.backoff_for(0)  # => ~1.0-1.5 (1.0 base + 0-0.5 jitter)
      #   policy.backoff_for(1)  # => ~2.0-2.5 (2.0 base + 0-0.5 jitter)
      #   policy.backoff_for(2)  # => ~4.0-4.5 (4.0 base + 0-0.5 jitter)
      def backoff_for(retry_num)
        interval = base_interval * (multiplier**retry_num)
        jitter_amount = jitter ? rand(0.0..jitter) : 0.0
        capped = [interval, max_interval].min
        capped + jitter_amount
      end

      # Check if an error should trigger a retry.
      #
      # @param error [StandardError] The error to check
      # @return [Boolean] True if this error should trigger a retry
      def retriable?(error)
        return ErrorClassification.retriable?(error) if retryable_errors.nil?

        retryable_errors.any? { |klass| error.is_a?(klass) }
      end
    end
  end
end
