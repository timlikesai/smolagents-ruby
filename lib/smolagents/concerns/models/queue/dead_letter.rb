require_relative "dlq_events"
require_relative "dlq_retry"

module Smolagents
  module Concerns
    module RequestQueue
      # Dead Letter Queue for failed requests.
      #
      # Captures requests that failed during processing for debugging,
      # analysis, or retry. Uses FIFO eviction when at capacity.
      #
      # @see RequestQueue For the main queue functionality
      # @see FailedRequest For the failure record type
      # @see DlqRetry For retry logic
      module DeadLetter
        include Events::Emitter
        include DlqEvents
        include DlqRetry

        DEFAULT_MAX_SIZE = 100

        # Enable the dead letter queue.
        def enable_dlq(max_size: DEFAULT_MAX_SIZE)
          @dlq_enabled = true
          @dlq_max_size = max_size
          @dlq_store = []
          @dlq_mutex = Mutex.new
          self
        end

        # Disable the dead letter queue and clear stored failures.
        def disable_dlq
          @dlq_enabled = false
          @dlq_store = nil
          @dlq_mutex = nil
          self
        end

        def dlq_enabled? = @dlq_enabled || false

        def dlq_size
          return 0 unless dlq_enabled?

          @dlq_mutex.synchronize { @dlq_store.size }
        end

        def failed_requests
          return [] unless dlq_enabled?

          @dlq_mutex.synchronize { @dlq_store.dup }
        end

        def retry_failed(count = 1)
          return [] unless dlq_enabled? && count.positive?

          pop_from_dlq(count).map { |failed| retry_single_request(failed) }
        end

        def clear_dlq
          return self unless dlq_enabled?

          @dlq_mutex.synchronize { @dlq_store.clear }
          self
        end

        private

        def add_to_dlq(request, error)
          return unless dlq_enabled?

          failed = build_failed_request(request, error, attempts: 1)
          store_failed_request(failed)
          emit_request_failed(failed)
        end

        def build_failed_request(request, error, attempts:)
          FailedRequest.new(
            request:, error: error.class.name, error_message: error.message,
            attempts:, failed_at: Time.now
          )
        end

        def store_failed_request(failed)
          @dlq_mutex.synchronize do
            @dlq_store.shift while @dlq_store.size >= @dlq_max_size
            @dlq_store << failed
          end
        end

        def pop_from_dlq(count)
          @dlq_mutex.synchronize { @dlq_store.shift(count) }
        end
      end
    end
  end
end
