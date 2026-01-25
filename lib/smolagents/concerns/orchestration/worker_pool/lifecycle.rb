module Smolagents
  module Concerns
    module Orchestration
      module WorkerPool
        # Worker pool lifecycle management.
        #
        # Handles starting, stopping, and scaling the worker pool.
        module Lifecycle
          # Starts the worker pool.
          # @return [self]
          def start_pool
            @pool_mutex.synchronize do
              return self if @pool_running

              @pool_running = true
              @pool_size.times { spawn_worker }
            end
            self
          end

          # Gracefully shuts down the pool.
          #
          # Sends shutdown signals to all workers and waits for them to exit.
          # Workers are expected to respond to shutdown signals promptly.
          #
          # @return [self]
          def shutdown_pool(timeout: 30) # rubocop:disable Lint/UnusedMethodArgument -- API compatibility
            @pool_mutex.synchronize do
              return self unless @pool_running

              @pool_running = false
              @pool_size.times { @work_queue.push(:shutdown) }
            end

            # Workers will exit when they receive :shutdown from the queue.
            # Queue.pop is blocking but returns immediately when data is pushed.
            @workers.each(&:join)
            @workers.clear
            self
          end

          # Scales the pool to a new size.
          # @param new_size [Integer] Target pool size
          # @return [self]
          # rubocop:disable Metrics/MethodLength -- scaling logic
          def scale_pool(new_size)
            @pool_mutex.synchronize do
              return self unless @pool_running

              diff = new_size - @pool_size
              @pool_size = new_size

              if diff.positive?
                diff.times { spawn_worker }
              elsif diff.negative?
                diff.abs.times { @work_queue.push(:shutdown) }
              end
            end
            self
          end
          # rubocop:enable Metrics/MethodLength

          private

          def spawn_worker
            worker = Thread.new { worker_loop }
            worker.name = "worker-#{@workers.size}"
            @workers << worker
          end

          def worker_loop
            loop do
              work = @work_queue.pop
              break if work == :shutdown

              execute_work(work)
            end
          end

          def execute_work(work)
            work.call
            @pool_mutex.synchronize { @completed_count += 1 }
          rescue StandardError => e
            @pool_mutex.synchronize { @error_count += 1 }
            handle_worker_error(e, work)
          end

          def handle_worker_error(error, work)
            # Hook for error handling - override in including class
            warn "Worker error: #{error.message}" if respond_to?(:warn)
            work[:on_error]&.call(error) if work.is_a?(Hash)
          end
        end
      end
    end
  end
end
