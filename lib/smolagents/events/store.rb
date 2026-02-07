# Event Store - Append-only storage with replay capability.

require_relative "store/backend"
require_relative "store/query"
require_relative "store/snapshot"
require_relative "store/storable"

module Smolagents
  module Events
    # Append-only event store enabling time-travel debugging and auditing.
    #
    # The EventStore persists events to durable storage and enables:
    # - **Replay** - Iterate events from any sequence for state reconstruction
    # - **Snapshots** - Capture state at checkpoints for faster replay
    # - **Query** - Filter events by type, time range, or custom predicates
    #
    # == Backends
    #
    # - +:memory+ - In-memory store (default, for testing)
    # - +String+ path - JSONL file storage with crash-safe writes
    #
    # @example Basic usage
    #   store = EventStore.new
    #   store.append(event)
    #   store.replay { |e| process(e) }
    #
    # @example File-backed persistent store
    #   store = EventStore.new(backend: "events.jsonl")
    #   store.append(Events::StepCompleted.create(step_number: 1, outcome: :success))
    #   store.count  #=> 1
    #
    # @example Replay from checkpoint
    #   store.replay(from: 100) { |e| apply(e) }
    #
    # @see Events::Emitter For event emission
    # @see EventStore::Backend For storage implementations
    class EventStore
      attr_reader :backend

      # Creates a new event store.
      #
      # @param backend [:memory, String] Storage backend (:memory or file path)
      # @param load_existing [Boolean] Load events from file on init (default: true)
      # @param max_events [Integer, nil] Maximum in-memory events (nil = unbounded)
      def initialize(backend: :memory, load_existing: true, max_events: nil)
        @backend = Backend.for(backend, max_events:)
        @subscribers = []
        @mutex = Mutex.new
        @backend.load if load_existing && @backend.respond_to?(:load)
      end

      # Appends an event to the store.
      #
      # Thread-safe. Persists immediately to backend if durable.
      # Notifies all subscribers after successful append.
      #
      # @param event [Object] Event object with id, sequence, created_at
      # @return [Object] The appended event
      def append(event)
        @mutex.synchronize { @backend.append(event) }
        notify_subscribers(event)
        event
      end

      # Replays events within a sequence range.
      #
      # @param from [Integer] Start sequence (inclusive, default: 0)
      # @param to [Integer, nil] End sequence (inclusive, nil = all)
      # @yield [event] Block called for each event
      # @return [Enumerator, nil] Enumerator if no block given
      def replay(from: 0, to: nil, &)
        events = @mutex.synchronize { @backend.events_in_range(from, to) }
        block_given? ? events.each(&) : events.each
      end

      # Queries events with filtering.
      #
      # @return [Query] Chainable query builder
      # @example Filter by type
      #   store.query.type(:step_completed).since(1.hour.ago).each { |e| }
      def query = Query.new(@backend, @mutex)

      # Returns the count of stored events.
      # @return [Integer]
      def count = @mutex.synchronize { @backend.count }

      # Returns all events (for small stores only).
      # @return [Array] Copy of all events
      def all = @mutex.synchronize { @backend.all }

      # Subscribes to new events.
      #
      # Thread-safe. Can be called concurrently with append/notify.
      #
      # @yield [event] Block called when events are appended
      # @return [self]
      def subscribe(&handler)
        @mutex.synchronize { @subscribers << handler }
        self
      end

      # Clears all subscribers.
      # @return [self]
      def unsubscribe_all
        @mutex.synchronize { @subscribers.clear }
        self
      end

      # Creates a snapshot of current state.
      #
      # @param sequence [Integer, nil] Sequence to snapshot at (default: latest)
      # @return [Snapshot] State snapshot
      def snapshot(sequence: nil)
        @mutex.synchronize do
          seq = sequence || @backend.last_sequence
          Snapshot.new(sequence: seq, event_count: @backend.count, timestamp: Time.now)
        end
      end

      # Closes the backend (for file-based stores).
      def close
        @backend.close if @backend.respond_to?(:close)
      end

      private

      def notify_subscribers(event)
        @mutex.synchronize { @subscribers.dup }.each do |subscriber|
          subscriber.call(event)
        rescue StandardError
          # Individual subscriber errors should not affect other subscribers
        end
      end
    end
  end
end
