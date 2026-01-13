module Smolagents
  module Events
    # Priority event queue for the event-driven ReAct loop.
    #
    # Events are stored with priorities and due times. The queue supports:
    # - Non-blocking pop operations (returns nil if nothing ready)
    # - Priority ordering (errors first, then immediate, then scheduled)
    # - Bounded iteration (max drain per call)
    # - Stale event cleanup (past-due threshold)
    #
    # @example Basic usage
    #   queue = EventQueue.new
    #   queue.push(event)
    #   ready_event = queue.pop_ready  # Non-blocking
    #
    # @example Priority ordering
    #   queue.push(tool_event, priority: :immediate)
    #   queue.push(error_event, priority: :error)
    #   queue.pop_ready  # Returns error_event first
    #
    # @example Draining multiple events
    #   events = queue.drain(max: 10)  # Get up to 10 ready events
    #
    class EventQueue
      # Priority levels (lower = higher priority)
      PRIORITY = {
        error: 0,        # Errors processed first
        immediate: 1,    # Ready events
        scheduled: 2,    # Future events (sorted by due_at)
        background: 3    # Low priority background work
      }.freeze

      # Raised when queue is full
      class QueueFullError < Smolagents::AgentError
        def initialize(max_depth)
          super("Event queue full (max: #{max_depth})")
        end
      end

      attr_reader :max_depth

      def initialize(max_depth: 1000)
        @events = []
        @max_depth = max_depth
        @mutex = Mutex.new
      end

      # Add event to queue (non-blocking).
      #
      # @param event [Object] Event to add (must respond to #ready?)
      # @param priority [Symbol] Priority level (:error, :immediate, :scheduled, :background)
      # @return [self] For chaining
      # @raise [QueueFullError] If queue is at max depth
      def push(event, priority: :immediate)
        @mutex.synchronize do
          raise QueueFullError, @max_depth if @events.size >= @max_depth

          @events << QueuedEvent.new(priority_key(priority, event), event)
          @events.sort_by!(&:sort_key)
        end
        self
      end

      alias << push

      # Get next ready event (non-blocking).
      #
      # @return [Object, nil] Next ready event, or nil if none ready
      def pop_ready
        @mutex.synchronize do
          idx = @events.find_index { |qe| qe.event.ready? }
          return nil unless idx

          @events.delete_at(idx)&.event
        end
      end

      # Peek at next ready event without removing.
      #
      # @return [Object, nil] Next ready event, or nil if none ready
      def peek_ready
        @mutex.synchronize do
          qe = @events.find { |e| e.event.ready? }
          qe&.event
        end
      end

      # Drain all ready events up to limit.
      #
      # @param max [Integer] Maximum events to drain
      # @return [Array<Object>] Ready events (may be fewer than max)
      def drain(max: 10)
        events = []
        max.times do
          event = pop_ready
          break unless event

          events << event
        end
        events
      end

      # Check if any events are ready.
      #
      # @return [Boolean] True if at least one event is ready
      def ready?
        @mutex.synchronize do
          @events.any? { |qe| qe.event.ready? }
        end
      end

      # Count of ready events.
      #
      # @return [Integer] Number of ready events
      def ready_count
        @mutex.synchronize do
          @events.count { |qe| qe.event.ready? }
        end
      end

      # Time until next scheduled event is due.
      #
      # @return [Float, nil] Seconds until next event, or nil if no scheduled events
      def next_due_in
        @mutex.synchronize do
          scheduled = @events.filter_map { |qe| qe.event.due_at if qe.event.respond_to?(:due_at) }.min
          return nil unless scheduled

          remaining = scheduled - Time.now
          remaining.positive? ? remaining : 0.0
        end
      end

      # Remove and return stale/past-due events.
      #
      # @param threshold [Integer] Seconds past due to consider stale
      # @return [Array<Object>] Removed stale events
      def cleanup_stale(threshold: 60)
        @mutex.synchronize do
          stale = @events.select { |qe| qe.event.respond_to?(:past_due?) && qe.event.past_due?(threshold:) }
          @events -= stale
          stale.map(&:event)
        end
      end

      # Remove all events matching a predicate.
      #
      # @yield [event] Block that returns true for events to remove
      # @return [Array<Object>] Removed events
      def remove_if
        @mutex.synchronize do
          removed = @events.select { |qe| yield(qe.event) }
          @events -= removed
          removed.map(&:event)
        end
      end

      # Clear all events.
      #
      # @return [self] For chaining
      def clear
        @mutex.synchronize { @events.clear }
        self
      end

      # Total number of events in queue.
      #
      # @return [Integer] Queue size
      def size
        @mutex.synchronize { @events.size }
      end

      # Check if queue is empty.
      #
      # @return [Boolean] True if no events
      def empty?
        @mutex.synchronize { @events.empty? }
      end

      # Check if queue is full.
      #
      # @return [Boolean] True if at max depth
      def full?
        @mutex.synchronize { @events.size >= @max_depth }
      end

      # Get queue statistics.
      #
      # @return [Hash] Stats about queue state
      def stats
        @mutex.synchronize do
          {
            size: @events.size,
            max_depth: @max_depth,
            ready_count: @events.count { |qe| qe.event.ready? },
            scheduled_count: @events.count { |qe| !qe.event.ready? },
            by_priority: @events.group_by { |qe| priority_name(qe.sort_key.first) }.transform_values(&:size)
          }
        end
      end

      # Internal wrapper for sorted storage
      QueuedEvent = Data.define(:sort_key, :event)

      private

      def priority_key(priority, event)
        base = PRIORITY.fetch(priority, PRIORITY[:immediate])
        # Sub-sort scheduled events by due_at
        due = event.respond_to?(:due_at) && event.due_at ? event.due_at.to_f : 0.0
        [base, due]
      end

      def priority_name(value)
        PRIORITY.key(value) || :unknown
      end
    end
  end
end
