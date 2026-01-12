module Smolagents
  module Concerns
    module Callbackable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def allowed_callbacks(*events)
          @allowed_callbacks = events.flatten
        end

        def callback_events
          @allowed_callbacks || Callbacks.events
        end

        def validates_callback_events? = !@allowed_callbacks.nil?
      end

      def callbacks
        @callbacks ||= Hash.new { |h, k| h[k] = [] }
      end

      def register_callback(event, callable = nil, validate: true, &block)
        validate_callback_event!(event) if validate
        callbacks[event] << (callable || block) if callable || block
        self
      end

      def clear_callbacks(event = nil)
        event ? callbacks.delete(event) : callbacks.clear
        self
      end

      def callback_registered?(event) = callbacks.key?(event) && callbacks[event].any?

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
