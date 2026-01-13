module Smolagents
  module Events
    # Consumer trait for event-handling components.
    #
    # Provides a mixin for classes that register and handle events from
    # an event-driven system. Handlers are stored and dispatched based on
    # event type, enabling decoupled event processing.
    #
    # The consumer pattern is used by agents and orchestrators to react
    # to events emitted during execution (tool calls, step completion, errors, etc.).
    #
    # Handlers can be registered using convenience event names (via {Mappings})
    # or full event classes. This allows code like:
    #   agent.on(:step_complete) { |e| ... }
    #   agent.on(StepCompleted) { |e| ... }  # Both work
    #
    # @example Registering event handlers
    #   class MyAgent
    #     include Events::Consumer
    #
    #     def initialize
    #       on(:step_complete) { |e| log("Step #{e.step_number}") }
    #       on(:error) { |e| alert("Error: #{e.error_message}") }
    #       on(:final_answer) { |e| save_result(e.output) }
    #     end
    #   end
    #
    # @example Processing events from a queue
    #   consumer = MyConsumer.new
    #   queue = Thread::Queue.new
    #   # ... events pushed to queue ...
    #   events = consumer.drain_events(queue)
    #
    # @see Events::Emitter For emitting events
    # @see Mappings For event name resolution
    #
    module Consumer
      # Called when module is included to add event_handlers attribute.
      # @param base [Class] The class including this module
      # @api private
      def self.included(base)
        base.attr_reader :event_handlers
      end

      # Setup hook for consumer initialization (no-op, handlers are lazy-loaded).
      # Provided for symmetry with {Emitter}.
      # @api private
      def setup_consumer; end

      # Registers a handler for events of a specific type.
      #
      # Handlers are stored per event type and called when {#consume} is
      # called with matching events. Multiple handlers can be registered
      # for the same event type - all will be called.
      #
      # The event_type can be specified as:
      # - A symbol name (e.g., :step_complete) resolved via {Mappings}
      # - A full event class (e.g., StepCompleted)
      #
      # @param event_type [Symbol, Class] Event type identifier or class
      # @yield [event] Block to call when event is consumed
      # @yieldparam event [Object] The event instance
      # @return [self] Returns self for method chaining
      #
      # @example Register with symbol (via Mappings)
      #   agent.on(:step_complete) { |e| puts "Step #{e.step_number}" }
      #
      # @example Register with event class
      #   agent.on(StepCompleted) { |e| puts "Step #{e.step_number}" }
      #
      # @example Chaining multiple handlers
      #   agent
      #     .on(:tool_complete) { |e| log_tool(e.tool_name) }
      #     .on(:error) { |e| alert(e.error_message) }
      #     .on(:final_answer) { |e| save(e.output) }
      #
      # @see Mappings for supported symbol names
      def on(event_type, &handler)
        @event_handlers ||= {}
        event_class = Mappings.valid?(event_type) ? Mappings.resolve(event_type) : event_type
        (@event_handlers[event_class] ||= []) << handler
        self
      end

      # Dispatches an event to all registered handlers.
      #
      # Finds handlers registered for the event's class and calls each with
      # the event. Errors in handlers are logged but don't prevent other
      # handlers from running or propagate to the caller.
      #
      # @param event [Object] The event to dispatch
      # @return [Array] Results from each handler (may be nil if handler errors)
      #
      # @example
      #   event = StepCompleted.create(step_number: 1, outcome: :success)
      #   consumer.consume(event)  # Calls all :step_complete handlers
      #
      # @see #on For registering handlers
      def consume(event)
        return [] unless @event_handlers

        handlers = @event_handlers[event.class] || []
        handlers.map { |h| h.call(event) }
      rescue StandardError => e
        warn "Consumer error processing #{event.class}: #{e.message}"
        []
      end

      # Drains all pending events from a queue and processes each.
      #
      # Pulls events from the queue (non-blocking) until empty, then
      # dispatches each event via {#consume}. Returns all events that
      # were processed.
      #
      # Useful for batch processing events after agent execution completes.
      #
      # @param queue [Thread::Queue] Queue to drain
      # @return [Array] All events that were in the queue
      #
      # @example Processing events after execution
      #   agent.run("task")
      #   events = agent.drain_events(event_queue)
      #   puts "Processed #{events.length} events"
      #
      # @see #consume For dispatching individual events
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

      # Clears all registered event handlers.
      #
      # Useful for resetting state or testing. After this call,
      # no handlers will be triggered for any events.
      #
      # @return [self] Returns self for method chaining
      #
      # @example
      #   agent.clear_handlers
      #   agent.on(:step_complete) { |e| ... }  # New handler
      def clear_handlers
        @event_handlers&.clear
        self
      end
    end
  end
end
