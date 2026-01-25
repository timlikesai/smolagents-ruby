module Smolagents
  module Types
    # Queue statistics snapshot.
    #
    # Immutable snapshot of queue state at a point in time, for monitoring
    # and performance analysis.
    #
    # @example Getting queue stats
    #   stats = model.queue_stats
    #   puts "Depth: #{stats.depth}, Processed: #{stats.total_processed}"
    #
    # @example Pattern matching on queue state
    #   case queue_stats
    #   in QueueStats[depth: 0, processing: false]
    #     :idle
    #   in QueueStats[depth:, processing: true] if depth > 10
    #     :overloaded
    #   in QueueStats[processing: true]
    #     :busy
    #   end
    #
    # @see Concerns::RequestQueue For queue management concern
    QueueStats = Data.define(:depth, :processing, :total_processed, :avg_wait_time, :max_wait_time) do
      include TypeSupport::Deconstructable

      # Whether the queue is currently empty.
      # @return [Boolean]
      def empty? = depth.zero?

      # Whether the queue is currently processing a request.
      # @return [Boolean]
      def busy? = processing

      # Whether the queue is idle (empty and not processing).
      # @return [Boolean]
      def idle? = empty? && !processing

      # Serializable hash representation.
      # @return [Hash]
      def to_h
        {
          depth:,
          processing:,
          total_processed:,
          avg_wait_time: avg_wait_time.round(2),
          max_wait_time: max_wait_time.round(2)
        }
      end

      class << self
        # Creates an empty/initial stats object.
        #
        # @return [QueueStats]
        def empty
          new(
            depth: 0,
            processing: false,
            total_processed: 0,
            avg_wait_time: 0.0,
            max_wait_time: 0.0
          )
        end
      end
    end
  end
end
