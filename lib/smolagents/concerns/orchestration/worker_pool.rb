require_relative "worker_pool/lifecycle"
require_relative "worker_pool/execution"

module Smolagents
  module Concerns
    module Orchestration
      # Thread pool for parallel work execution.
      #
      # WorkerPool manages a fixed number of worker threads that process
      # work items from a shared queue. Supports graceful shutdown and
      # dynamic scaling.
      #
      # @example Basic usage
      #   pool = WorkerPool.new(size: 4)
      #   pool.submit { expensive_computation }
      #   pool.shutdown
      #
      # @see WorkQueue For priority-based work queuing
      # @see ParallelAgents For agent-specific parallel execution
      module WorkerPool
        def self.included(base)
          base.include(Lifecycle)
          base.include(Execution)
        end

        # Default number of workers (CPU cores - 1, clamped to 2-8)
        DEFAULT_POOL_SIZE = (Etc.nprocessors - 1).clamp(2, 8)

        # Initialize worker pool state.
        # @param size [Integer] Number of worker threads
        def init_worker_pool(size: DEFAULT_POOL_SIZE)
          @pool_size = size
          @workers = []
          @work_queue = Thread::Queue.new
          @pool_mutex = Mutex.new
          @pool_running = false
          @completed_count = 0
          @error_count = 0
        end

        # @return [Integer] Current pool size
        def pool_size = @pool_size

        # @return [Integer] Number of active workers
        def active_workers = @workers&.count(&:alive?) || 0

        # @return [Integer] Pending work items
        def pending_work = @work_queue&.size || 0

        # @return [Boolean] True if pool is running
        def pool_running? = @pool_running

        # Pool statistics snapshot.
        # @return [Hash]
        def pool_stats
          @pool_mutex.synchronize do
            {
              size: @pool_size,
              active: active_workers,
              pending: pending_work,
              completed: @completed_count,
              errors: @error_count,
              running: @pool_running
            }
          end
        end
      end
    end
  end
end
