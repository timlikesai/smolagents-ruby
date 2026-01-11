module Smolagents
  module Monitoring
    class CallbackRegistry
      def initialize
        @callbacks = Hash.new { |h, k| h[k] = [] }
      end

      def register(event, &block)
        @callbacks[event] << block if block_given?
      end

      def trigger(event, *)
        @callbacks[event].each do |callback|
          callback.call(*)
        rescue StandardError => e
          warn "Callback error for #{event}: #{e.message}"
        end
      end

      def registered?(event)
        @callbacks[event].any?
      end

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
