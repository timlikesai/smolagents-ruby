require_relative "async_queue"

module Smolagents
  module Events
    # Consumer trait for event-handling components.
    #
    # Provides handler registration and event dispatching. Handlers can be
    # registered using symbol names or event classes.
    #
    # @example Registering handlers
    #   agent.on(:step_complete) { |e| log("Step #{e.step_number}") }
    #   agent.on(:error) { |e| alert(e.error_message) }
    #
    # @see Events::Emitter For emitting events
    # @see Mappings For event name resolution
    #
    module Consumer
      # Represents a handler failure during event consumption.
      # @!attribute [r] handler
      #   @return [Proc] The handler that failed
      # @!attribute [r] event
      #   @return [Object] The event being processed
      # @!attribute [r] error
      #   @return [Exception] The error that occurred
      # @!attribute [r] timestamp
      #   @return [Time] When the failure occurred
      HandlerFailure = Data.define(:handler, :event, :error, :timestamp) do
        def event_class = event.class.name
        def error_class = error.class.name
        def error_message = error.message
      end

      # @api private
      def self.included(base)
        base.attr_reader :event_handlers, :failed_handlers
      end

      # Setup hook for consumer initialization.
      # @api private
      def setup_consumer; end

      # Registers a handler for events of a specific type.
      # @param event_type [Symbol, Class] Event type identifier or class
      # @yield [event] Block to call when event is consumed
      # @return [self]
      def on(event_type, &handler)
        @event_handlers ||= {}
        event_class = Mappings.valid?(event_type) ? Mappings.resolve(event_type) : event_type
        (@event_handlers[event_class] ||= []) << handler
        self
      end

      # Dispatches an event to all registered handlers.
      #
      # Each handler is called in sequence. If a handler raises an error,
      # it is recorded in {#failed_handlers} and an error event is emitted,
      # but remaining handlers still execute.
      #
      # @param event [Object] The event to dispatch
      # @return [Array] Results from each handler (nil for failed handlers)
      def consume(event)
        return [] unless @event_handlers

        handlers = @event_handlers[event.class] || []
        handlers.map { |handler| call_handler(handler, event) }
      end

      # Returns whether any handlers have failed.
      # @return [Boolean]
      def handlers_failed? = @failed_handlers&.any? || false

      # Clears the failed handlers list.
      # @return [self]
      def clear_failed_handlers
        @failed_handlers&.clear
        self
      end

      # Drains events from a queue with optional timeout.
      #
      # Pulls events from the queue until empty or timeout reached.
      # Also waits for async event processing to complete.
      #
      # @param queue [Thread::Queue] Queue to drain
      # @param timeout [Numeric, nil] Max seconds to wait (nil = no limit)
      # @return [Array] All events that were processed
      def drain_events(queue, timeout: nil)
        deadline = timeout ? Time.now + timeout : nil
        events = drain_queue(queue, deadline)
        wait_for_async(deadline)
        events
      end

      # Clears all registered event handlers.
      # @return [self]
      def clear_handlers
        @event_handlers&.clear
        self
      end

      # Shuts down async processing gracefully.
      # @param timeout [Numeric] Max seconds to wait
      # @return [Boolean] True if shutdown cleanly
      def shutdown_events(timeout: 5)
        AsyncQueue.shutdown(timeout:)
      end

      private

      def call_handler(handler, event)
        handler.call(event)
      rescue StandardError => e
        record_handler_failure(handler, event, e)
        nil
      end

      def record_handler_failure(handler, event, error)
        @failed_handlers ||= []
        failure = HandlerFailure.new(handler:, event:, error:, timestamp: Time.now)
        @failed_handlers << failure
        warn "Consumer error processing #{event.class}: #{error.message}"
        emit_handler_error(failure) if respond_to?(:emit, true)
      end

      def emit_handler_error(failure)
        error_event = ErrorOccurred.create(
          error: failure.error,
          context: { event_class: failure.event_class, handler: failure.handler.to_s },
          recoverable: true
        )
        emit(error_event)
      end

      def drain_queue(queue, deadline)
        events = []
        while (event = pop_event(queue, deadline))
          events << event
          consume(event)
        end
        events
      end

      def pop_event(queue, deadline)
        return nil if deadline && Time.now >= deadline

        queue.pop(true)
      rescue ThreadError
        nil
      end

      def wait_for_async(deadline)
        return unless AsyncQueue.running?

        Thread.pass until AsyncQueue.pending_count.zero? || (deadline && Time.now >= deadline)
      end
    end
  end
end
