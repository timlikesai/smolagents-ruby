module Smolagents
  module Concerns
    module RequestQueue
      # Retry logic for the Dead Letter Queue.
      #
      # Handles retrying failed requests and re-queueing them if they fail again.
      #
      # @see DeadLetter For the main DLQ functionality
      module DlqRetry
        private

        # Retry a single failed request.
        def retry_single_request(failed)
          emit_request_retried(failed)
          generate_without_queue(failed.request.messages, **failed.request.kwargs)
        rescue StandardError => e
          requeue_failed(failed, e)
          e
        end

        # Requeue a failed request with incremented attempt count.
        def requeue_failed(failed, error)
          return unless dlq_enabled?

          updated = build_failed_request(failed.request, error, attempts: failed.attempts + 1)
          @dlq_mutex.synchronize { @dlq_store << updated }
        end
      end
    end
  end
end
