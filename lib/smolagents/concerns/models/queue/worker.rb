module Smolagents
  module Concerns
    module RequestQueue
      # Background worker thread that processes queued requests sequentially.
      module Worker
        include Events::Emitter

        # Maximum iterations for worker loop (prevents runaway).
        MAX_QUEUE_ITERATIONS = 10_000
        # Timeout for graceful shutdown (seconds).
        SHUTDOWN_TIMEOUT = 5

        private

        # Start background worker thread for queue processing.
        # @return [void]
        def start_worker_thread
          @worker_thread = Thread.new { process_queue_loop }
          @worker_thread.name = "RequestQueue-Worker-#{object_id}"
        end

        # Stop worker thread gracefully with timeout.
        # @return [void]
        def stop_worker_thread
          @request_queue&.push(nil) # Poison pill pattern
          # Graceful shutdown: wait for worker to finish current request
          @worker_thread&.join(SHUTDOWN_TIMEOUT)
          @worker_thread&.kill if @worker_thread&.alive?
          @worker_thread = nil
        end

        # Main worker loop processing requests from queue.
        # @return [void]
        def process_queue_loop
          MAX_QUEUE_ITERATIONS.times do
            break if @request_queue.closed?

            request = @request_queue.pop # Blocking pop
            break if request.nil? # Poison pill received

            process_request(request)
          end
        rescue StandardError => e
          warn "RequestQueue worker error: #{e.message}" if $DEBUG
        end

        # Process a single queued request.
        # @param request [QueuedRequest] Request to process
        # @return [void]
        def process_request(request)
          @processing = true
          update_queue_stats(request.wait_time)
          emit_queue_started(request.wait_time)
          execute_queued_request(request)
        ensure
          @processing = false
        end

        # Execute request and return result or handle error.
        # @param request [QueuedRequest] Request with messages and kwargs
        # @return [void]
        def execute_queued_request(request)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = generate_without_queue(request.messages, **request.kwargs)
          request.result_queue.push(result)
          emit_queue_completed(start_time, success: true)
        rescue StandardError => e
          request.result_queue.push(e)
          add_to_dlq(request, e) if respond_to?(:add_to_dlq, true)
          emit_queue_completed(start_time, success: false) if defined?(start_time)
        end

        # Emit event when queue request starts.
        # @param wait_time [Float] Time spent waiting in queue
        # @return [void]
        def emit_queue_started(wait_time)
          emit(Events::QueueRequestStarted.create(
                 model_id: model_id_for_events, queue_depth:, wait_time:
               ))
        end

        # Emit event when queue request completes.
        # @param start_time [Float] Monotonic start time
        # @param success [Boolean] Whether execution succeeded
        # @return [void]
        def emit_queue_completed(start_time, success:)
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          emit(Events::QueueRequestCompleted.create(
                 model_id: model_id_for_events, duration:, success:
               ))
        end

        # Get model ID for event emission.
        # @return [String] Model ID or class name
        def model_id_for_events
          respond_to?(:model_id) ? model_id : self.class.name
        end

        # Update queue statistics with wait time.
        # @param wait_time [Float] Time spent in queue
        # @return [void]
        def update_queue_stats(wait_time)
          @queue_stats[:mutex].synchronize do
            @queue_stats[:wait_times] << wait_time
            @queue_stats[:total] += 1
          end
        end
      end
    end
  end
end
