module Smolagents
  module Concerns
    module RequestQueue
      # Dead Letter Queue for failed requests.
      #
      # Captures requests that failed during processing for debugging,
      # analysis, or retry. Uses FIFO eviction when at capacity.
      #
      # @example Basic DLQ operations
      #   model.enable_queue
      #   model.enable_dlq(max_size: 50)
      #
      #   # Check for failed requests
      #   model.dlq_size           #=> 3
      #   model.failed_requests    #=> [FailedRequest, ...]
      #
      #   # Retry failed requests
      #   model.retry_failed(1)    # Retry oldest failure
      #
      # @see RequestQueue For the main queue functionality
      module DeadLetter
        include Events::Emitter

        DEFAULT_MAX_SIZE = 100

        # Enable the dead letter queue.
        # @param max_size [Integer] Maximum number of failed requests to keep
        # @return [self]
        def enable_dlq(max_size: DEFAULT_MAX_SIZE)
          @dlq_enabled = true
          @dlq_max_size = max_size
          @dlq_store = []
          @dlq_mutex = Mutex.new
          self
        end

        # Disable the dead letter queue and clear stored failures.
        # @return [self]
        def disable_dlq
          @dlq_enabled = false
          @dlq_store = nil
          @dlq_mutex = nil
          self
        end

        # Check if DLQ is enabled.
        # @return [Boolean]
        def dlq_enabled? = @dlq_enabled || false

        # Number of failed requests in the DLQ.
        # @return [Integer]
        def dlq_size
          return 0 unless dlq_enabled?

          @dlq_mutex.synchronize { @dlq_store.size }
        end

        # Get all failed requests.
        # @return [Array<FailedRequest>] Copy of failed requests (oldest first)
        def failed_requests
          return [] unless dlq_enabled?

          @dlq_mutex.synchronize { @dlq_store.dup }
        end

        # Retry a specific number of failed requests from the DLQ.
        # @param count [Integer] Number of requests to retry (default: 1)
        # @return [Array<Object>] Results from retried requests
        def retry_failed(count = 1)
          return [] unless dlq_enabled? && count.positive?

          to_retry = pop_from_dlq(count)
          to_retry.map { |failed| retry_single_request(failed) }
        end

        # Clear all failed requests.
        # @return [self]
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
            @dlq_store.shift while @dlq_store.size >= @dlq_max_size # FIFO eviction
            @dlq_store << failed
          end
        end

        def pop_from_dlq(count)
          @dlq_mutex.synchronize { @dlq_store.shift(count) }
        end

        def retry_single_request(failed)
          original = failed.request
          emit_request_retried(failed)

          # Re-execute the original request
          generate_without_queue(original.messages, **original.kwargs)
        rescue StandardError => e
          # Re-add to DLQ with incremented attempts if retry fails
          requeue_failed(failed, e)
          e # Return error as result
        end

        def requeue_failed(failed, error)
          return unless dlq_enabled?

          updated = build_failed_request(failed.request, error, attempts: failed.attempts + 1)
          @dlq_mutex.synchronize { @dlq_store << updated }
        end

        def emit_request_failed(failed)
          return unless defined?(Events::RequestFailed)

          emit(Events::RequestFailed.create(
                 model_id: model_id_for_events,
                 error: failed.error,
                 error_message: failed.error_message,
                 dlq_size:
               ))
        end

        def emit_request_retried(failed)
          return unless defined?(Events::RequestRetried)

          emit(Events::RequestRetried.create(
                 model_id: model_id_for_events,
                 attempt: failed.attempts + 1,
                 original_error: failed.error
               ))
        end
      end

      # Immutable record of a failed request.
      #
      # Captures the original request, error details, and retry attempts
      # for debugging and analysis.
      #
      # @!attribute [r] request
      #   @return [QueuedRequest] The original request that failed
      # @!attribute [r] error
      #   @return [String] Error class name
      # @!attribute [r] error_message
      #   @return [String] Error message
      # @!attribute [r] attempts
      #   @return [Integer] Number of execution attempts
      # @!attribute [r] failed_at
      #   @return [Time] When the failure occurred
      FailedRequest = Data.define(:request, :error, :error_message, :attempts, :failed_at) do
        # Convert to a hash for serialization.
        # @return [Hash]
        def to_h
          {
            request_id: request.id,
            error:,
            error_message:,
            attempts:,
            failed_at: failed_at.iso8601
          }
        end

        # Time since the failure occurred.
        # @return [Float] Seconds since failure
        def age = Time.now - failed_at
      end
    end
  end
end
