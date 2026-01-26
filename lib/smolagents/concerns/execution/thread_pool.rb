module Smolagents
  module Concerns
    # Thread pool with enforced concurrency limit.
    #
    # Blocks when max_threads is reached, waiting for a slot to become
    # available. Used for parallel tool call execution with a maximum
    # concurrency limit.
    #
    # @example
    #   pool = ThreadPool.new(4)
    #   threads = 3.times.map { pool.spawn { do_work } }
    #   threads.each(&:join)
    class ThreadPool
      # @param max_threads [Integer] Maximum concurrent threads (enforced)
      def initialize(max_threads)
        @max_threads = max_threads
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @active = 0
      end

      # Spawn a new thread to execute a block.
      #
      # Blocks if max_threads limit is reached, waiting for a slot.
      #
      # @yield Block to execute in a new thread
      # @return [Thread] The spawned thread
      def spawn
        @mutex.synchronize do
          @condition.wait(@mutex) while @active >= @max_threads
          @active += 1
        end
        Thread.new do
          yield
        ensure
          @mutex.synchronize do
            @active -= 1
            @condition.signal
          end
        end
      end
    end
  end
end
