# frozen_string_literal: true

module Smolagents
  module Monitoring
    # Registry for agent event callbacks.
    # Allows registering and triggering callbacks for agent lifecycle events.
    #
    # @example Register callbacks
    #   registry = CallbackRegistry.new
    #   registry.register(:step_complete) { |step| puts "Step done: #{step}" }
    #   registry.trigger(:step_complete, step_data)
    class CallbackRegistry
      def initialize
        @callbacks = Hash.new { |h, k| h[k] = [] }
      end

      # Register a callback for an event.
      #
      # @param event [Symbol] event name
      # @yield callback block
      # @return [void]
      def register(event, &block)
        @callbacks[event] << block if block_given?
      end

      # Trigger all callbacks for an event.
      #
      # @param event [Symbol] event name
      # @param args [Array] arguments to pass to callbacks
      # @return [void]
      def trigger(event, *args)
        @callbacks[event].each do |callback|
          callback.call(*args)
        rescue StandardError => e
          warn "Callback error for #{event}: #{e.message}"
        end
      end

      # Check if any callbacks are registered for an event.
      #
      # @param event [Symbol] event name
      # @return [Boolean]
      def registered?(event)
        @callbacks[event].any?
      end

      # Clear all callbacks for an event.
      #
      # @param event [Symbol] event name (nil clears all)
      # @return [void]
      def clear(event = nil)
        if event
          @callbacks.delete(event)
        else
          @callbacks.clear
        end
      end
    end
  end
end
