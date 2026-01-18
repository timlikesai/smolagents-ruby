module Smolagents
  module Concerns
    module RequestQueue
      # Background worker thread that processes queued requests sequentially.
      module Worker
        # Maximum iterations for worker loop (prevents runaway).
        MAX_QUEUE_ITERATIONS = 10_000
        # Timeout for graceful shutdown (seconds).
        SHUTDOWN_TIMEOUT = 5

        private

        def start_worker_thread
          @worker_thread = Thread.new { process_queue_loop }
          @worker_thread.name = "RequestQueue-Worker-#{object_id}"
        end

        def stop_worker_thread
          @request_queue&.push(nil) # Poison pill pattern
          # Graceful shutdown: wait for worker to finish current request
          @worker_thread&.join(SHUTDOWN_TIMEOUT)
          @worker_thread&.kill if @worker_thread&.alive?
          @worker_thread = nil
        end

        # Worker thread - waits for requests and processes them.
        # Background worker threads waiting for work is OK (like Node.js thread pool).
        # The main event loop should never block - only background workers.
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

        def process_request(request)
          @processing = true
          update_queue_stats(request.wait_time)
          emit_queue_started(request.wait_time)
          execute_queued_request(request)
        ensure
          @processing = false
        end

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

        def emit_queue_started(wait_time)
          return unless respond_to?(:emit_event, true)

          emit_event(Events::QueueRequestStarted.create(
                       model_id: model_id_for_events, queue_depth:, wait_time:
                     ))
        end

        def emit_queue_completed(start_time, success:)
          return unless respond_to?(:emit_event, true)

          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          emit_event(Events::QueueRequestCompleted.create(
                       model_id: model_id_for_events, duration:, success:
                     ))
        end

        def model_id_for_events
          respond_to?(:model_id) ? model_id : self.class.name
        end

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
