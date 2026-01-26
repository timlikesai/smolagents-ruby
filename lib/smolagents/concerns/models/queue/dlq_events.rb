module Smolagents
  module Concerns
    module RequestQueue
      # Event emission for the Dead Letter Queue.
      #
      # Emits events when requests fail or are retried, enabling monitoring
      # and observability of the DLQ system.
      #
      # @see DeadLetter For the main DLQ functionality
      module DlqEvents
        private

        # Emit request failure event.
        # @param failed [FailedRequest] Failed request record
        # @return [void]
        def emit_request_failed(failed)
          return unless defined?(Events::RequestFailed)

          emit(Events::RequestFailed.create(
                 model_id: model_id_for_events,
                 error: failed.error,
                 error_message: failed.error_message,
                 dlq_size:
               ))
        end

        # Emit request retry event.
        # @param failed [FailedRequest] Failed request being retried
        # @return [void]
        def emit_request_retried(failed)
          return unless defined?(Events::RequestRetried)

          emit(Events::RequestRetried.create(
                 model_id: model_id_for_events,
                 attempt: failed.attempts + 1,
                 original_error: failed.error
               ))
        end
      end
    end
  end
end
