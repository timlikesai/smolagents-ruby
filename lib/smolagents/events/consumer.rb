module Smolagents
  module Events
    # Consumer trait for event-driven handlers.
    #
    # Components include this module to register handlers and process events.
    #
    # @example
    #   class MyAgent
    #     include Events::Consumer
    #
    #     def initialize
    #       on(StepCompleted) { |e| log(e.step_number) }
    #       on(ErrorOccurred) { |e| alert(e.error_message) }
    #     end
    #   end
    #
    module Consumer
      def self.included(base)
        base.attr_reader :event_handlers
      end

      # Setup hook (no-op, handlers initialized lazily).
      def setup_consumer; end

      # Register a handler for an event type.
      def on(event_type, &handler)
        @event_handlers ||= {}
        event_class = Mappings.valid?(event_type) ? Mappings.resolve(event_type) : event_type
        (@event_handlers[event_class] ||= []) << handler
        self
      end

      # Dispatch an event to registered handlers.
      def consume(event)
        return [] unless @event_handlers

        handlers = @event_handlers[event.class] || []
        handlers.map { |h| h.call(event) }
      rescue StandardError => e
        warn "Consumer error processing #{event.class}: #{e.message}"
        []
      end

      # Drain events from queue and consume each.
      def drain_events(queue)
        events = []
        while (event = begin
          queue.pop(true)
        rescue StandardError
          nil
        end)
          events << event
          consume(event)
        end
        events
      end

      # Clear all handlers.
      def clear_handlers
        @event_handlers&.clear
        self
      end
    end
  end
end
