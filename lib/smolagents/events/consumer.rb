# Event consumption - subscribing to and handling events.

require_relative "base"
require_relative "async_queue"

module Smolagents
  module Events
    # Event consumption module.
    #
    # Provides ergonomic APIs for subscribing to events:
    # - Multi-event: `on(:step_complete, :task_complete) { }`
    # - Category: `on_tools { }`, `on_lifecycle { }`
    # - Keyword destructuring: `on(:event) { |field:, **| }`
    #
    # @example Basic subscription
    #   class MyObserver
    #     include Events::Consumer
    #
    #     def initialize
    #       on(:step_complete) { |e| log("Step #{e.step_number}") }
    #       on(:error) { |e| alert(e.error_message) }
    #     end
    #   end
    #
    # @example Keyword destructuring
    #   on(:step_complete) { |step_number:, outcome:, **| puts step_number }
    #
    module Consumer
      include Base

      # Handler failure record.
      HandlerFailure = Data.define(:handler, :event, :error, :timestamp) do
        def event_class = event.class.name
        def error_class = error.class.name
        def error_message = error.message
      end

      def self.included(base)
        base.include(Base)
        base.attr_reader :event_handlers, :failed_handlers
      end

      # Setup hook for consumer initialization.
      # @api private
      def setup_consumer; end

      # Subscribes to one or more event types.
      #
      # @param event_types [Array<Symbol, Class>] Event types to subscribe to
      # @yield [event] Handler block
      # @return [self]
      #
      # @example Single event
      #   on(:step_complete) { |e| puts e.step_number }
      #
      # @example Multiple events
      #   on(:step_complete, :task_complete) { |e| log(e) }
      #
      # @example Keyword destructuring
      #   on(:step_complete) { |step_number:, outcome:, **| puts step_number }
      #
      def on(*event_types, &handler)
        @event_handlers ||= {}

        event_types.each do |event_type|
          event_class = resolve_event_class(event_type)
          (@event_handlers[event_class] ||= []) << wrap_handler(handler)
        end

        self
      end

      # --- Category Subscriptions ---

      # Subscribes to all tool-related events.
      def on_tools(&)
        on(:tool_call, :tool_complete, :tool_isolation_started,
           :tool_isolation_completed, :resource_violation, :tool_retrying, &)
      end

      # Subscribes to lifecycle events.
      def on_lifecycle(&)
        on(:step_complete, :task_complete, &)
      end

      # Subscribes to error-related events.
      def on_errors(&)
        on(:error, :rate_limit, :request_failed, &)
      end

      # Subscribes to model events.
      def on_models(&)
        on(:model_generate_requested, :model_generate_completed,
           :model_changed, :model_discovered, &)
      end

      # Subscribes to sub-agent events.
      def on_agents(&)
        on(:agent_launch, :agent_progress, :agent_complete, :spawn_restricted, &)
      end

      # Subscribes to resilience events.
      def on_resilience(&)
        on(:retry, :failover, :recovery, :circuit_state_changed, &)
      end

      # --- Consumption ---

      # Dispatches an event to registered handlers.
      # @param event [Object]
      # @return [Array] Handler results
      def consume(event)
        return [] unless @event_handlers

        handlers = @event_handlers[event.class] || []
        handlers.map { |h| safe_call(h, event) }
      end

      # Returns whether any handlers have failed.
      def handlers_failed? = @failed_handlers&.any? || false

      # Clears failed handlers list.
      def clear_failed_handlers
        @failed_handlers&.clear
        self
      end

      # Clears all registered handlers.
      def clear_handlers
        @event_handlers&.clear
        self
      end

      # Shuts down async event processing.
      def shutdown_events(timeout: 5)
        AsyncQueue.shutdown(timeout:)
      end

      # Drains events from a queue.
      def drain_events(queue, timeout: nil)
        deadline = timeout ? Time.now + timeout : nil
        events = []

        while (event = pop_event(queue, deadline))
          events << event
          consume(event)
        end

        wait_for_async(deadline)
        events
      end

      private

      def wrap_handler(handler)
        params = handler.parameters
        wants_kwargs = params.any? { |type, _| %i[keyreq key].include?(type) }

        if wants_kwargs
          ->(event) { handler.call(**event.to_h) }
        else
          handler
        end
      end

      def safe_call(handler, event)
        handler.call(event)
      rescue StandardError => e
        record_failure(handler, event, e)
        nil
      end

      def record_failure(handler, event, error)
        @failed_handlers ||= []
        @failed_handlers << HandlerFailure.new(
          handler:, event:, error:, timestamp: Time.now
        )
        # Use event system for observability - no warn/puts
        emit_error(error, context: { event_class: event.class.name }, recoverable: true) if respond_to?(:emit_error)
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
