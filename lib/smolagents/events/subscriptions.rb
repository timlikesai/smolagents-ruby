module Smolagents
  module Events
    # DSL-driven event subscription concern for builders.
    #
    # Provides a declarative way to define event subscriptions with:
    # - Configurable storage key (:handlers or :callbacks)
    # - Configurable entry format (tuple or hash)
    # - Auto-generated convenience methods (on_step, on_error, etc.)
    #
    # @example Usage in a builder
    #   class MyBuilder
    #     include Events::Subscriptions
    #
    #     configure_events key: :handlers, format: :tuple
    #     define_handler :step, maps_to: :step_complete
    #     define_handler :task, maps_to: :task_complete
    #     define_handler :error
    #   end
    #
    #   # Generates:
    #   # - on(event_type, &block) method
    #   # - on_step(&) convenience method
    #   # - on_task(&) convenience method
    #   # - on_error(&) convenience method
    module Subscriptions
      def self.included(base)
        base.extend(ClassMethods)
        # Set defaults
        base.instance_variable_set(:@events_key, :handlers)
        base.instance_variable_set(:@events_format, :tuple)
      end

      # Class-level DSL for configuring event subscriptions.
      module ClassMethods
        # Configure event storage.
        #
        # @param key [Symbol] Configuration key for storing handlers (:handlers, :callbacks)
        # @param format [Symbol] Entry format - :tuple for [event, block], :hash for {type:, handler:}
        def configure_events(key:, format: :tuple)
          @events_key = key
          @events_format = format
        end

        # Define a convenience subscription method.
        #
        # @param name [Symbol] Shortcut name (e.g., :step generates on_step)
        # @param maps_to [Symbol] Event type to subscribe to (defaults to name)
        def define_handler(name, maps_to: name)
          define_method(:"on_#{name}") { |&block| on(maps_to, &block) }
        end

        # @api private
        def events_key = @events_key
        # @api private
        def events_format = @events_format
      end

      # Subscribe to events. Accepts event class or convenience name.
      #
      # @param event_type [Class, Symbol] Event class or name
      # @yield [event] Block to call when event fires
      # @return [self] New builder with handler registered
      def on(event_type, &block)
        check_frozen!
        entry = build_event_entry(event_type, block)
        key = self.class.events_key
        with_config(key => configuration[key] + [entry])
      end

      private

      def build_event_entry(event_type, block)
        case self.class.events_format
        when :hash then { type: event_type, handler: block }
        else [event_type, block]
        end
      end
    end
  end
end
