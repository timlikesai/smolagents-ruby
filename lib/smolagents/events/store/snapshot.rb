# Snapshot type for event store checkpoints.

module Smolagents
  module Events
    class EventStore
      # Immutable snapshot of event store state at a point in time.
      #
      # Snapshots enable faster state reconstruction by providing
      # a checkpoint to replay from, rather than replaying all events.
      #
      # @example Create and use snapshot
      #   snapshot = store.snapshot
      #   # ... more events appended ...
      #   store.replay(from: snapshot.sequence + 1) { |e| apply(e) }
      Snapshot = Data.define(:sequence, :event_count, :timestamp) do
        # Checks if the snapshot is stale (store has newer events).
        #
        # @param current_sequence [Integer] Current store sequence
        # @return [Boolean]
        def stale?(current_sequence) = sequence < current_sequence

        # Returns age of snapshot in seconds.
        # @return [Float]
        def age = Time.now - timestamp

        # Serializes snapshot to hash.
        # @return [Hash]
        def to_h
          { sequence:, event_count:, timestamp: timestamp.iso8601 }
        end

        # Creates snapshot from hash.
        # @param data [Hash] Serialized snapshot data
        # @return [Snapshot]
        def self.from_h(data)
          new(
            sequence: data[:sequence],
            event_count: data[:event_count],
            timestamp: Time.parse(data[:timestamp])
          )
        end
      end
    end
  end
end
