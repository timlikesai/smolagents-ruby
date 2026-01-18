module Smolagents
  module Models
    module ResilientModelConcerns
      # Event notification helpers for resilient model operations.
      # Emits failover, retry, recovery, and error events.
      module Notifications
        private

        def notify_failover(from_model, to_model, error, attempt)
          from_id = from_model.respond_to?(:model_id) ? from_model.model_id : from_model.to_s
          to_id = to_model.respond_to?(:model_id) ? to_model.model_id : (to_model&.to_s || "none")
          event = Events::FailoverOccurred.create(from_model_id: from_id, to_model_id: to_id, error:, attempt:)
          emit_event(event) if emitting?
          consume(event)
        end

        def notify_error(error, attempt, model)
          model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
          emit_error(error, context: { model_id:, attempt: }, recoverable: true) if emitting?
        end

        def notify_recovery(model, attempt)
          model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
          event = Events::RecoveryCompleted.create(model_id:, attempts_before_recovery: attempt)
          emit_event(event) if emitting?
          consume(event)
        end

        def notify_retry(model, error, attempt, max_attempts, suggested_interval)
          model_id = model.respond_to?(:model_id) ? model.model_id : model.to_s
          event = Events::RetryRequested.create(model_id:, error:, attempt:, max_attempts:, suggested_interval:)
          emit_event(event) if emitting?
          consume(event)
        end
      end
    end
  end
end
