# Query builder for filtering events.

module Smolagents
  module Events
    class EventStore
      # Chainable query builder for filtering events.
      #
      # Provides a fluent interface for querying stored events
      # by type, time range, sequence, and custom predicates.
      #
      # @example Query by type and time
      #   store.query
      #     .type(:step_complete, :task_complete)
      #     .since(1.hour.ago)
      #     .each { |e| process(e) }
      #
      # @example Query with custom predicate
      #   store.query
      #     .where { |e| e.outcome == :success }
      #     .limit(10)
      #     .to_a
      class Query
        def initialize(backend, mutex)
          @backend = backend
          @mutex = mutex
          @filters = []
          @limit_count = nil
          @offset_count = 0
        end

        # Filters by event type(s).
        #
        # @param types [Array<Symbol, Class>] Event types to include
        # @return [Query] self for chaining
        def type(*types)
          type_names = types.map { |t| normalize_type(t) }
          @filters << ->(e) { type_names.include?(e.event_name) }
          self
        end

        # Filters events after a timestamp.
        #
        # @param time [Time] Start time (exclusive)
        # @return [Query] self for chaining
        def since(time)
          @filters << ->(e) { e.created_at > time }
          self
        end

        # Filters events before a timestamp.
        #
        # @param time [Time] End time (exclusive)
        # @return [Query] self for chaining
        def before(time)
          @filters << ->(e) { e.created_at < time }
          self
        end

        # Filters events in a time range.
        #
        # @param range [Range<Time>] Time range
        # @return [Query] self for chaining
        def between(range)
          @filters << ->(e) { range.cover?(e.created_at) }
          self
        end

        # Filters by sequence range.
        #
        # @param from [Integer] Start sequence (inclusive)
        # @param to [Integer, nil] End sequence (inclusive)
        # @return [Query] self for chaining
        def sequence(from:, to: nil)
          @filters << ->(e) { e.sequence >= from && (to.nil? || e.sequence <= to) }
          self
        end

        # Filters with custom predicate.
        #
        # @yield [event] Predicate block
        # @return [Query] self for chaining
        def where(&predicate)
          @filters << predicate
          self
        end

        # Limits result count.
        #
        # @param count [Integer] Maximum events to return
        # @return [Query] self for chaining
        def limit(count)
          @limit_count = count
          self
        end

        # Skips first N results.
        #
        # @param count [Integer] Events to skip
        # @return [Query] self for chaining
        def offset(count)
          @offset_count = count
          self
        end

        # Executes query and returns results.
        #
        # @return [Array] Matching events
        def to_a
          events = @mutex.synchronize { @backend.all }
          events = apply_filters(events)
          events = events.drop(@offset_count) if @offset_count.positive?
          events = events.take(@limit_count) if @limit_count
          events
        end

        # Iterates matching events.
        #
        # @yield [event] Block for each matching event
        # @return [Enumerator] if no block given
        def each(&) = block_given? ? to_a.each(&) : to_a.each

        # Returns first matching event.
        # @return [Object, nil]
        def first = limit(1).to_a.first

        # Returns last matching event.
        # @return [Object, nil]
        def last = to_a.last

        # Counts matching events.
        # @return [Integer]
        def count = to_a.size

        # Checks if any events match.
        # @return [Boolean]
        def any? = !to_a.empty?

        # Checks if no events match.
        # @return [Boolean]
        def none? = to_a.empty?

        private

        def normalize_type(type)
          case type
          when Class then type.event_name
          else type.to_s
          end
        end

        def apply_filters(events)
          return events if @filters.empty?

          events.select { |e| @filters.all? { |f| f.call(e) } }
        end
      end
    end
  end
end
