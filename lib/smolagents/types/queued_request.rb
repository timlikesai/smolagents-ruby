module Smolagents
  module Types
    # Request wrapper for queue management.
    #
    # Wraps a generation request with metadata for tracking and scheduling.
    # Used by RequestQueue concern to manage pending model requests.
    #
    # @example Creating a queued request
    #   request = QueuedRequest.new(
    #     id: SecureRandom.uuid,
    #     priority: :high,
    #     messages: [{ role: "user", content: "Hello" }],
    #     kwargs: { temperature: 0.7 },
    #     result_queue: Thread::Queue.new,
    #     queued_at: Time.now
    #   )
    #
    # @example Checking priority
    #   request.high_priority?  # => true
    #   request.wait_time       # => 0.5 (seconds since queued)
    #
    # @see Concerns::RequestQueue For queue management concern
    QueuedRequest = Data.define(:id, :priority, :messages, :kwargs, :result_queue, :queued_at) do
      include TypeSupport::Deconstructable

      # Calculate how long the request has been waiting.
      # @return [Float] Elapsed time in seconds since the request was queued
      def wait_time = Time.now - queued_at

      # Check if this request has high priority.
      # @return [Boolean] True if priority is :high
      def high_priority? = priority == :high

      # Check if this request has normal priority.
      # @return [Boolean] True if priority is :normal
      def normal_priority? = priority == :normal

      class << self
        # Creates a high priority request.
        #
        # @param messages [Array<Hash>] Messages to send to the model
        # @param kwargs [Hash] Additional generation parameters
        # @param result_queue [Thread::Queue] Queue for returning results
        # @return [QueuedRequest]
        def high_priority(messages:, kwargs: {}, result_queue: Thread::Queue.new)
          new(
            id: SecureRandom.uuid,
            priority: :high,
            messages:,
            kwargs:,
            result_queue:,
            queued_at: Time.now
          )
        end

        # Creates a normal priority request.
        #
        # @param messages [Array<Hash>] Messages to send to the model
        # @param kwargs [Hash] Additional generation parameters
        # @param result_queue [Thread::Queue] Queue for returning results
        # @return [QueuedRequest]
        def normal_priority(messages:, kwargs: {}, result_queue: Thread::Queue.new)
          new(
            id: SecureRandom.uuid,
            priority: :normal,
            messages:,
            kwargs:,
            result_queue:,
            queued_at: Time.now
          )
        end
      end
    end
  end
end
