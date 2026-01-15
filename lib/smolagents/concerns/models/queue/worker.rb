module Smolagents
  module Concerns
    module RequestQueue
      # Background worker thread that processes queued requests sequentially.
      module Worker
        # Maximum iterations for worker loop (prevents runaway).
        MAX_QUEUE_ITERATIONS = 10_000

        private

        def start_worker_thread
          @worker_thread = Thread.new { process_queue_loop }
          @worker_thread.name = "RequestQueue-Worker-#{object_id}"
        end

        def stop_worker_thread
          @request_queue&.push(nil) # Poison pill pattern
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
          request.result_queue.push(generate_without_queue(request.messages, **request.kwargs))
        rescue StandardError => e
          request.result_queue.push(e)
        ensure
          @processing = false
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
