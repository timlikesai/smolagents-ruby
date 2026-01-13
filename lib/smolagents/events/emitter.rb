module Smolagents
  module Events
    # Producer trait for event-driven components.
    #
    # Components include this module to emit events to a Thread::Queue.
    # Events are pushed without knowing who consumes them.
    #
    # @example
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
    module Emitter
      def self.included(base)
        base.attr_accessor :event_queue
      end

      # Connect to an event queue (Thread::Queue).
      def connect_to(queue)
        @event_queue = queue
        self
      end

      # Push an event to the queue.
      def emit(event)
        @event_queue&.push(event)
        event
      end

      # Check if connected to a queue.
      def emitting?
        !@event_queue.nil?
      end

      # Emit an error event.
      def emit_error(error, context: {}, recoverable: false)
        emit(ErrorOccurred.create(error:, context:, recoverable:))
      end

      # Convenience for emitting events (alias for backward compat during migration).
      alias emit_event emit
    end
  end
end
