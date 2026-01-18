module Smolagents
  module Concerns
    # Event data types for reliability features.
    #
    # Immutable records for retry and failover events, allowing
    # subscribers to log, monitor, or react to reliability events.
    module ReliabilityEvents
      # Event emitted before a retry attempt.
      #
      # Immutable record of a retry attempt with calculated backoff interval.
      # Allows subscribers to log retries or adjust scheduling.
      #
      # @!attribute [r] model
      #   @return [Model] The model being retried
      # @!attribute [r] error
      #   @return [StandardError] The error that triggered the retry
      # @!attribute [r] attempt
      #   @return [Integer] Current attempt number (1-indexed)
      # @!attribute [r] max_attempts
      #   @return [Integer] Maximum attempts allowed
      # @!attribute [r] suggested_interval
      #   @return [Float] Suggested wait time in seconds before next retry
      #
      # @example Converting to hash
      #   event = RetryEvent.new(model:, error:, attempt: 2, max_attempts: 3, suggested_interval: 2.0)
      #   event.to_h
      #   # => { model: "gpt-4", error: "timeout", attempt: 2, max_attempts: 3, suggested_interval: 2.0 }
      RetryEvent = Data.define(:model, :error, :attempt, :max_attempts, :suggested_interval) do
        # Convert retry event to a Hash for serialization or logging.
        #
        # @return [Hash] Hash with :model (model_id), :error (message), :attempt, :max_attempts, :suggested_interval
        def to_h
          { model: model.model_id, error: error.message, attempt:, max_attempts:, suggested_interval: }
        end
      end

      # Failover event emitted when switching to a backup model.
      #
      # Immutable record of a failover event with source, destination, and error details.
      # Allows monitoring and logging of model switching events.
      #
      # @!attribute [r] from_model
      #   @return [Model] The model that failed
      # @!attribute [r] to_model
      #   @return [Model, nil] The backup model being switched to (nil if none available)
      # @!attribute [r] error
      #   @return [StandardError] The error that triggered failover
      # @!attribute [r] attempt
      #   @return [Integer] Attempt number when failover occurred
      # @!attribute [r] timestamp
      #   @return [Time] When the failover occurred
      #
      # @example Converting to hash
      #   event = FailoverEvent.new(from_model: m1, to_model: m2, error:, attempt: 1, timestamp: Time.now)
      #   event.to_h
      #   # => { from: m1, to: m2, error: "Connection failed", attempt: 1, timestamp: "2024-01-15T10:30:00Z" }
      FailoverEvent = Data.define(:from_model, :to_model, :error, :attempt, :timestamp) do
        # Convert failover event to a Hash for serialization or logging.
        #
        # @return [Hash] Hash with :from, :to, :error (message), :attempt, :timestamp (ISO8601)
        def to_h
          { from: from_model, to: to_model, error: error.message, attempt:, timestamp: timestamp.iso8601 }
        end
      end
    end
  end
end
