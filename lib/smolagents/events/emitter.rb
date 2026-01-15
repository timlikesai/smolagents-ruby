module Smolagents
  module Events
    # Producer trait for event-emitting components.
    #
    # Provides a mixin for classes that emit events to a Thread::Queue.
    # Events are pushed decoupled from consumption - emitters don't know or care
    # who handles the events.
    #
    # Components using this trait emit events throughout their execution,
    # enabling observability, logging, metrics, and tracing without
    # coupling producers to consumers.
    #
    # @example Emitting events from a model
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
    # @example Connecting to a queue
    #   queue = Thread::Queue.new
    #   model = MyModel.new
    #   model.connect_to(queue)
    #   model.generate(messages)
    #   event = queue.pop  # => ModelGenerateRequested event
    #
    # @see Events::Consumer For consuming events
    # @see Thread::Queue Ruby's thread-safe queue
    #
    module Emitter
      # Called when module is included to add event_queue attribute.
      # @param base [Class] The class including this module
      # @api private
      def self.included(base)
        base.attr_accessor :event_queue
      end

      # Connects this component to an event queue.
      #
      # Once connected, all {#emit} calls will push events to the queue.
      # Callers can check {#emitting?} to verify connection status.
      #
      # @param queue [Thread::Queue] The event queue to connect to
      # @return [self] Returns self for method chaining
      #
      # @example
      #   queue = Thread::Queue.new
      #   component.connect_to(queue)
      #   component.emit(some_event)
      def connect_to(queue)
        @event_queue = queue
        self
      end

      # Emits an event to the connected queue.
      #
      # If not connected to a queue, the event is created but discarded.
      # This allows code to emit events without checking connection status.
      #
      # @param event [Object] The event to emit (usually a Data.define instance)
      # @return [Object] Returns the event (for chaining if needed)
      #
      # @example
      #   event = ToolCallRequested.create(tool_name: "search", args: {})
      #   emit(event)
      #
      # @see Events for available event types
      def emit(event)
        @event_queue&.push(event)
        event
      end

      # Checks if this component is connected to an event queue.
      #
      # @return [Boolean] True if connected, false if not
      def emitting? = !@event_queue.nil?

      # Emits an error event to the connected queue.
      #
      # Convenience method for creating and emitting ErrorOccurred events.
      # Useful for consistent error handling and observability.
      #
      # @param error [Exception] The exception that occurred
      # @param context [Hash] Additional context about the error
      # @param recoverable [Boolean] Whether the error can be recovered from
      # @return [ErrorOccurred] The created and emitted error event
      #
      # @example
      #   begin
      #     tool.execute
      #   rescue StandardError => e
      #     emit_error(e, context: { tool_name: "search" }, recoverable: true)
      #   end
      def emit_error(error, context: {}, recoverable: false)
        emit(ErrorOccurred.create(error:, context:, recoverable:))
      end

      # Alias for {#emit} for backward compatibility.
      # @see #emit
      alias emit_event emit
    end
  end
end
