module Smolagents
  module Builders
    module ModelBuilderCallbacks
      # Callback registration methods for ModelBuilder.
      #
      # Provides chainable methods for subscribing to model events:
      # failover, error, recovery, model change, and queue wait.
      # Register a callback for an event.
      #
      # @param event [Symbol] Event type
      # @yield Block to call when event occurs
      # @return [ModelBuilder] New builder with callback added
      def on(event, &block)
        with_config(callbacks: configuration[:callbacks] + [{ type: event, handler: block }])
      end

      # Subscribe to model failover events.
      #
      # @yield [event] Failover event with from_model and to_model
      # @return [ModelBuilder]
      def on_failover(&) = on(:failover, &)

      # Subscribe to error events.
      #
      # @yield [error, attempt, model] Error details
      # @return [ModelBuilder]
      def on_error(&) = on(:error, &)

      # Subscribe to model recovery events.
      #
      # @yield [model, attempt] Recovery details
      # @return [ModelBuilder]
      def on_recovery(&) = on(:recovery, &)

      # Subscribe to model change events.
      #
      # @yield [old_model_id, new_model_id] Model IDs
      # @return [ModelBuilder]
      def on_model_change(&) = on(:model_change, &)

      # Subscribe to queue wait events.
      #
      # @yield [position, elapsed_seconds] Queue position and wait time
      # @return [ModelBuilder]
      def on_queue_wait(&) = on(:queue_wait, &)
    end
  end
end
