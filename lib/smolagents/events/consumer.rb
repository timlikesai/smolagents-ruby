module Smolagents
  module Events
    # Consumer trait for event-driven handlers.
    #
    # Any class that processes events can include this module to get
    # standardized event consumption capabilities. Consumers register
    # handlers for specific event types (like subscribing to topics).
    #
    # Think of this like a Kafka consumer or SQS listener:
    # - Consumers subscribe to event types
    # - Events are dispatched to matching handlers
    # - Handlers run to completion (no blocking)
    #
    # @example Agent as event consumer
    #   class CodeAgent
    #     include Events::Consumer
    #
    #     def initialize
    #       # Subscribe to specific event types
    #       on_event(Events::ToolCallCompleted) { |e| handle_tool_result(e) }
    #       on_event(Events::RateLimitHit) { |e| handle_rate_limit(e) }
    #       on_event(Events::ErrorOccurred) { |e| handle_error(e) }
    #     end
    #   end
    #
    # @example Pattern matching on events
    #   consumer.on_event(Events::StepCompleted) do |event|
    #     case event
    #     in { outcome: :success } then log_success(event)
    #     in { outcome: :error } then log_error(event)
    #     in { outcome: :rate_limited } then log_retry(event)
    #     end
    #   end
    #
    module Consumer
      def self.included(base)
        base.attr_reader :event_handlers
      end

      # Initialize consumer with empty handler registry.
      def setup_consumer
        @event_handlers = Hash.new { |h, k| h[k] = [] }
        @catch_all_handlers = []
      end

      # Subscribe to a specific event type.
      #
      # @param event_class [Class] Event type to handle
      # @param filter [Proc, nil] Optional filter predicate
      # @yield [event] Handler block
      # @return [self] For chaining
      def on_event(event_class, filter: nil, &handler)
        @event_handlers ||= Hash.new { |h, k| h[k] = [] }
        @event_handlers[event_class] << EventSubscription.new(handler, filter)
        self
      end

      # Subscribe to all events (catch-all handler).
      #
      # @yield [event] Handler block for any event
      # @return [self] For chaining
      def on_any_event(&handler)
        @catch_all_handlers ||= []
        @catch_all_handlers << handler
        self
      end

      # Process a single event by dispatching to handlers.
      #
      # @param event [Object] Event to process
      # @return [Array<Object>] Results from handlers
      def consume(event)
        results = []

        # Specific handlers first
        @event_handlers&.[](event.class)&.each do |subscription|
          next unless subscription.matches?(event)

          results << subscription.handle(event)
        end

        # Catch-all handlers
        @catch_all_handlers&.each do |handler|
          results << handler.call(event)
        end

        results
      rescue StandardError => e
        handle_consumer_error(event, e)
        []
      end

      # Process multiple events.
      #
      # @param events [Array<Object>] Events to process
      # @return [Hash<Object, Array>] Results keyed by event
      def consume_batch(events)
        events.to_h { |event| [event, consume(event)] }
      end

      # Check if any handlers are registered for an event type.
      #
      # @param event_class [Class] Event type to check
      # @return [Boolean] True if handlers exist
      def handles?(event_class)
        @event_handlers&.key?(event_class) && @event_handlers[event_class].any?
      end

      # Count of registered handlers.
      #
      # @return [Integer] Total handler count
      def handler_count
        specific = @event_handlers&.values&.sum(&:size) || 0
        catch_all = @catch_all_handlers&.size || 0
        specific + catch_all
      end

      # Clear all handlers.
      #
      # @return [self] For chaining
      def clear_handlers
        @event_handlers&.clear
        @catch_all_handlers&.clear
        self
      end

      # Internal subscription wrapper
      EventSubscription = Data.define(:handler, :filter) do
        def matches?(event)
          filter.nil? || filter.call(event)
        end

        def handle(event)
          handler.call(event)
        end
      end

      private

      def handle_consumer_error(event, error)
        warn "Consumer error processing #{event.class}: #{error.message}"
      end
    end
  end
end
