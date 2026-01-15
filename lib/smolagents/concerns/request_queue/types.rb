module Smolagents
  module Concerns
    module RequestQueue
      # Request wrapper for queue management (immutable Data class - Ruby 4.0 pattern).
      #
      # Wraps a generation request with metadata for tracking and scheduling.
      #
      # @!attribute [r] id
      #   @return [String] Unique request identifier (UUID)
      # @!attribute [r] priority
      #   @return [Symbol] Priority level (:high or :normal)
      # @!attribute [r] messages
      #   @return [Array<Hash>] Messages to send to the model (frozen)
      # @!attribute [r] kwargs
      #   @return [Hash] Additional generation parameters (frozen)
      # @!attribute [r] result_queue
      #   @return [Thread::Queue] Queue for returning results
      # @!attribute [r] queued_at
      #   @return [Time] When the request was enqueued
      QueuedRequest = Data.define(:id, :priority, :messages, :kwargs, :result_queue, :queued_at) do
        # Calculate how long the request has been waiting.
        # @return [Float] Elapsed time in seconds since the request was queued
        def wait_time = Time.now - queued_at

        # Check if this request has high priority.
        # @return [Boolean] True if priority is :high
        def high_priority? = priority == :high
      end

      # Queue statistics (immutable).
      #
      # Snapshot of queue state at a point in time, for monitoring
      # and performance analysis.
      #
      # @!attribute [r] depth
      #   @return [Integer] Number of requests currently in queue
      # @!attribute [r] processing
      #   @return [Boolean] Whether a request is currently being processed
      # @!attribute [r] total_processed
      #   @return [Integer] Total requests successfully processed
      # @!attribute [r] avg_wait_time
      #   @return [Float] Average wait time of recent requests (seconds)
      # @!attribute [r] max_wait_time
      #   @return [Float] Maximum wait time of recent requests (seconds)
      QueueStats = Data.define(:depth, :processing, :total_processed, :avg_wait_time, :max_wait_time) do
        # Convert queue statistics to a Hash for serialization or logging.
        # @return [Hash] Hash with queue statistics
        def to_h
          {
            depth:,
            processing:,
            total_processed:,
            avg_wait_time: avg_wait_time.round(2),
            max_wait_time: max_wait_time.round(2)
          }
        end
      end
    end
  end
end
