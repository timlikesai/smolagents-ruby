module Smolagents
  module Concerns
    # Simple non-blocking thread pool for parallel execution.
    #
    # Spawns threads immediately without blocking, tracking only the
    # active count. Used for parallel tool call execution with a maximum
    # concurrency limit.
    #
    # @example
    #   pool = ThreadPool.new(4)
    #   threads = 3.times.map { pool.spawn { do_work } }
    #   threads.each(&:join)
    class ThreadPool
      # @param max_threads [Integer] Maximum concurrent threads (informational)
      def initialize(max_threads)
        @max_threads = max_threads
        @mutex = Mutex.new
        @active = 0
      end

      # Spawn a new thread to execute a block.
      #
      # Immediately spawns without blocking, even if max_threads exceeded.
      # The max_threads limit is informational only.
      #
      # @yield Block to execute in a new thread
      # @return [Thread] The spawned thread
      def spawn
        @mutex.synchronize { @active += 1 }
        Thread.new do
          yield
        ensure
          @mutex.synchronize { @active -= 1 }
        end
      end
    end
  end
end
