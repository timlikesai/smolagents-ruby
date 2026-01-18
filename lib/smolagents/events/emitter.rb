require_relative "async_queue"

module Smolagents
  module Events
    # Producer trait for event-emitting components.
    #
    # Provides async event emission by default. Events are processed in a
    # background thread to avoid blocking the reasoning loop.
    #
    # @example Emitting events (async by default)
    #   class MyModel
    #     include Events::Emitter
    #
    #     def generate(messages)
    #       emit(ModelGenerateRequested.create(messages:))
    #       response = call_api(messages)
    #       emit(ModelGenerateCompleted.create(response:))
    #       response
    #     end
    #   end
    #
    # @see Events::Consumer For consuming events
    # @see Events::AsyncQueue For background processing
    #
    module Emitter
      # @api private
      def self.included(base)
        base.attr_accessor :event_queue
      end

      # Connects this component to an event queue.
      # @param queue [Thread::Queue] The event queue to connect to
      # @return [self]
      def connect_to(queue)
        @event_queue = queue
        self
      end

      # Emits an event asynchronously (default).
      #
      # If connected to a queue, pushes to queue for external processing.
      # Otherwise, dispatches via background thread to local handlers.
      #
      # @param event [Object] The event to emit
      # @return [Object] The event
      def emit(event)
        if @event_queue
          @event_queue.push(event)
        elsif respond_to?(:consume) && @event_handlers&.any?
          AsyncQueue.push(event) { |e| consume(e) }
        end
        event
      end

      # Emits an event synchronously (blocks until handled).
      #
      # Use when you need handler results or ordering guarantees.
      #
      # @param event [Object] The event to emit
      # @return [Object] The event
      def emit_sync(event)
        if @event_queue
          @event_queue.push(event)
        elsif respond_to?(:consume) && @event_handlers&.any?
          consume(event)
        end
        event
      end

      # Checks if events should be emitted.
      #
      # Returns true if either connected to an event queue or has
      # registered event handlers.
      #
      # @return [Boolean]
      def emitting?
        !!(@event_queue || @event_handlers&.any?)
      end

      # Emits an error event.
      # @param error [Exception] The exception
      # @param context [Hash] Additional context
      # @param recoverable [Boolean] Whether recoverable
      # @return [ErrorOccurred]
      def emit_error(error, context: {}, recoverable: false)
        emit(ErrorOccurred.create(error:, context:, recoverable:))
      end

      # Alias for backward compatibility.
      alias emit_event emit
    end
  end
end
