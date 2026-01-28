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

          # Shuts down the pool.
          #
          # Sends shutdown signals to all workers. Workers exit asynchronously
          # when they receive the signal. No blocking - returns immediately.
          #
          # @param timeout [Numeric] Unused, kept for API compatibility
          # @return [self]
          # rubocop:disable Lint/UnusedMethodArgument -- timeout kept for API compat with blocking impls
          def shutdown_pool(timeout: 1)
            @pool_mutex.synchronize do
              return self unless @pool_running

              @pool_running = false
              @pool_size.times { @work_queue.push(:shutdown) }
              @workers.clear # Clear immediately - workers exit asynchronously
            end
            self
          end
          # rubocop:enable Lint/UnusedMethodArgument

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

          def execute_work(work_item)
            result = work_item[:work].call
            @pool_mutex.synchronize { @completed_count += 1 }
            work_item[:on_complete]&.call(result)
          rescue StandardError => e
            # Count FIRST, callback SECOND - ensures count is visible when callback completes
            @pool_mutex.synchronize { @error_count += 1 }
            work_item[:on_error]&.call(e)
            handle_worker_error(e)
          end

          def handle_worker_error(error)
            # Hook for error handling - override in including class
            warn "Worker error: #{error.message}" if respond_to?(:warn)
          end
        end
      end
    end
  end
end
