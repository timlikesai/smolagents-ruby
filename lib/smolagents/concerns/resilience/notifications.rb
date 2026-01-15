module Smolagents
  module Concerns
    # Event notification helpers for model reliability.
    #
    # Provides methods to emit failover, retry, recovery, and error events.
    module ReliabilityNotifications
      # Emit a failover event.
      #
      # @param from_model [Model] Model that failed
      # @param to_model [Model, nil] Model being switched to
      # @param error [StandardError] Error that triggered failover
      # @param attempt [Integer] Current attempt number
      def notify_failover(from_model, to_model, error, attempt)
        event = Events::FailoverOccurred.create(
          from_model_id: from_model.model_id, to_model_id: to_model&.model_id || "none", error:, attempt:
        )
        emit_event(event) if emitting?
        consume(event)
      end

      # Emit an error event.
      #
      # @param error [StandardError] Error that occurred
      # @param attempt [Integer] Current attempt number
      # @param model [Model] Model that errored
      def notify_error(error, attempt, model)
        emit_error(error, context: { model_id: model.model_id, attempt: }, recoverable: true) if emitting?
      end

      # Emit a recovery event.
      #
      # @param model [Model] Model that recovered
      # @param attempt [Integer] Attempt number when recovery occurred
      def notify_recovery(model, attempt)
        event = Events::RecoveryCompleted.create(model_id: model.model_id, attempts_before_recovery: attempt)
        emit_event(event) if emitting?
        consume(event)
      end

      # Emit a retry event.
      #
      # @param model [Model] Model being retried
      # @param error [StandardError] Error that triggered retry
      # @param attempt [Integer] Current attempt number
      # @param max_attempts [Integer] Maximum attempts allowed
      # @param suggested_interval [Float] Suggested wait time
      def notify_retry(model, error, attempt, max_attempts, suggested_interval)
        event = Events::RetryRequested.create(
          model_id: model.model_id, error:, attempt:, max_attempts:, suggested_interval:
        )
        emit_event(event) if emitting?
        consume(event)
      end
    end
  end
end
