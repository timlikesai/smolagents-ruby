module Smolagents
  module Concerns
    module Reliability
      # Event subscriptions for model reliability.
      #
      # Provides convenience methods to subscribe to reliability events
      # like failover, error, recovery, and retry.
      #
      # @example Subscribe to events
      #   model.on_failover { |e| log("Failover: #{e.from_model_id} -> #{e.to_model_id}") }
      #   model.on_retry { |e| log("Retry #{e.attempt}/#{e.max_attempts}") }
      module Subscriptions
        # Subscribe to failover events.
        # @yield [Events::FailoverOccurred] Block called on failover
        # @return [self] For chaining
        def on_failover(&) = on(Events::FailoverOccurred, &)

        # Subscribe to error events.
        # @yield [Events::ErrorOccurred] Block called on error
        # @return [self] For chaining
        def on_error(&) = on(Events::ErrorOccurred, &)

        # Subscribe to recovery events.
        # @yield [Events::RecoveryCompleted] Block called when retry succeeds
        # @return [self] For chaining
        def on_recovery(&) = on(Events::RecoveryCompleted, &)

        # Subscribe to retry events.
        # @yield [Events::RetryRequested] Block called before retry
        # @return [self] For chaining
        def on_retry(&) = on(Events::RetryRequested, &)
      end
    end
  end
end
