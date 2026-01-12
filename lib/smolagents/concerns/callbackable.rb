module Smolagents
  module Concerns
    # Adds event-based callback registration and triggering to any class.
    #
    # Provides a flexible callback system where handlers can be registered
    # for named events and triggered with keyword arguments. Supports
    # validation of event names and automatic argument matching based on
    # callback arity.
    #
    # @example Basic callback registration (used by AgentBuilder.on)
    #   class MyAgent
    #     include Concerns::Callbackable
    #
    #     def run
    #       trigger_callbacks(:step_complete, step: current_step)
    #     end
    #   end
    #
    #   agent = MyAgent.new
    #   agent.register_callback(:step_complete) { |step:| puts step }
    #
    # @example Restricting allowed events
    #   class MyTool
    #     include Concerns::Callbackable
    #     allowed_callbacks :before_execute, :after_execute
    #   end
    #
    # @example Chainable registration (returns self)
    #   agent
    #     .register_callback(:step_complete) { |s| log(s) }
    #     .register_callback(:error) { |e| alert(e) }
    #
    # @see Callbacks Standard event definitions and signatures
    module Callbackable
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class-level methods for configuring callback behavior
      module ClassMethods
        # Restricts which callback events this class accepts.
        # @param events [Array<Symbol>] Allowed event names
        def allowed_callbacks(*events)
          @allowed_callbacks = events.flatten
        end

        # Returns the list of valid callback events for this class.
        # @return [Array<Symbol>] Allowed events, or global Callbacks.events if unrestricted
        def callback_events
          @allowed_callbacks || Callbacks.events
        end

        # Whether this class restricts callback events.
        # @return [Boolean] True if allowed_callbacks was called
        def validates_callback_events? = !@allowed_callbacks.nil?
      end

      # Returns the callbacks hash (event => array of handlers).
      # @return [Hash<Symbol, Array<Proc>>] Registered callbacks by event
      def callbacks
        @callbacks ||= Hash.new { |hash, key| hash[key] = [] }
      end

      # Registers a callback handler for an event.
      #
      # @param event [Symbol] Event name to listen for
      # @param callable [#call, nil] Callable object (Proc, lambda, or any object with #call)
      # @param validate [Boolean] Whether to validate the event name
      # @yield Block to call when event fires (alternative to callable)
      # @return [self] For method chaining
      # @raise [Callbacks::InvalidCallbackError] If event is invalid and validate is true
      def register_callback(event, callable = nil, validate: true, &block)
        validate_callback_event!(event) if validate
        callbacks[event] << (callable || block) if callable || block
        self
      end

      # Removes all callbacks for an event, or all callbacks entirely.
      #
      # @param event [Symbol, nil] Event to clear, or nil to clear all
      # @return [self] For method chaining
      def clear_callbacks(event = nil)
        event ? callbacks.delete(event) : callbacks.clear
        self
      end

      # Checks if any callbacks are registered for an event.
      # @param event [Symbol] Event name
      # @return [Boolean] True if at least one handler is registered
      def callback_registered?(event) = callbacks.key?(event) && callbacks[event].any?

      # Counts registered callbacks.
      # @param event [Symbol, nil] Specific event, or nil for total count
      # @return [Integer] Number of registered callbacks
      def callback_count(event = nil)
        event ? callbacks[event].size : callbacks.values.sum(&:size)
      end

      private

      def trigger_callbacks(event, validate: false, **kwargs)
        Callbacks.validate_args!(event, kwargs) if validate
        positional_args = extract_positional_args(event, kwargs)

        callbacks[event].each do |callback|
          invoke_callback(event, callback, positional_args, kwargs)
        end
      end

      def extract_positional_args(event, kwargs)
        return [] unless Callbacks.valid_event?(event)

        sig = Callbacks::SIGNATURES[event]
        (sig.required_args + sig.optional_args).filter_map { |key| kwargs[key] }
      end

      def invoke_callback(event, callback, positional_args, kwargs)
        case callback.arity
        when 0 then callback.call
        when -1 then callback.call(*positional_args)
        else
          invoke_with_matching_arity(callback, positional_args, kwargs)
        end
      rescue StandardError => e
        handle_callback_error(event, e)
      end

      def invoke_with_matching_arity(callback, positional_args, kwargs)
        if callback.parameters.any? { |type, _| %i[keyreq key keyrest].include?(type) }
          callback.call(**kwargs)
        else
          callback.call(*positional_args.take(callback.arity))
        end
      end

      def handle_callback_error(event, error)
        warn "Callback error for #{event}: #{error.message}"
      end

      def validate_callback_event!(event)
        if self.class.validates_callback_events?
          return if self.class.callback_events.include?(event)

          valid_events = self.class.callback_events.map(&:inspect).join(", ")
          raise Callbacks::InvalidCallbackError,
                "Unknown callback event '#{event}' for #{self.class}. Valid events: #{valid_events}"
        else
          Callbacks.validate_event!(event)
        end
      end
    end
  end
end
