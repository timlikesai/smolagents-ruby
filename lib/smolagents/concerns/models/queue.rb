require_relative "queue/types"
require_relative "queue/operations"
require_relative "queue/worker"
require_relative "queue/dead_letter"

module Smolagents
  module Concerns
    # Request queueing for models that can only handle one request at a time.
    #
    # Uses Ruby 4.0's Thread::Queue for thread-safe producer-consumer pattern.
    # All completion notifications are emitted as events.
    #
    # @example Basic serialized execution
    #   model = OpenAIModel.lm_studio("local-model")
    #   model.extend(RequestQueue)
    #   model.enable_queue
    #
    #   # These will execute one at a time, even from different threads
    #   Thread.new { model.queued_generate(messages1) }
    #   Thread.new { model.queued_generate(messages2) }
    #
    # @example Priority requests
    #   model.queued_generate(messages, priority: :high)
    #
    module RequestQueue
      def self.extended(base)
        base.extend(Events::Emitter) unless base.singleton_class.include?(Events::Emitter)
        base.extend(Operations)
        base.extend(Worker)
        base.extend(DeadLetter)
        base.instance_variable_set(:@queue_enabled, false)
        base.instance_variable_set(:@queue_max_depth, nil)
        base.instance_variable_set(:@queue_stats, { total: 0, wait_times: [], mutex: Mutex.new })
        base.instance_variable_set(:@request_queue, nil)
        base.instance_variable_set(:@worker_thread, nil)
        base.instance_variable_set(:@processing, false)
        base.instance_variable_set(:@dlq_enabled, false)
      end

      # Enable request queueing.
      # @param max_depth [Integer, nil] Maximum queue depth (default: 100, nil = unlimited)
      # @return [self]
      def enable_queue(max_depth: :default, **_ignored)
        return self if @queue_enabled

        @queue_enabled = true
        @queue_max_depth = resolve_max_depth(max_depth)
        @request_queue = Thread::Queue.new
        start_worker_thread
        self
      end

      private

      def resolve_max_depth(max_depth)
        case max_depth
        when :default then Config.default(:execution, :default_queue_depth)
        when nil then nil # Explicit nil = unlimited
        else max_depth
        end
      end

      public

      # Disable request queueing and stop the worker thread.
      # @return [self]
      def disable_queue
        return self unless @queue_enabled

        @queue_enabled = false
        stop_worker_thread
        @request_queue = nil
        self
      end

      # Check if queueing is enabled.
      # @return [Boolean]
      def queue_enabled? = @queue_enabled

      # Current number of requests waiting.
      # @return [Integer]
      def queue_depth = @request_queue&.size || 0

      # Check if currently processing a request.
      # @return [Boolean]
      def processing? = @processing

      # Get queue statistics.
      # @return [QueueStats]
      def queue_stats
        @queue_stats[:mutex].synchronize do
          wait_times = @queue_stats[:wait_times].last(100)
          QueueStats.new(
            depth: queue_depth,
            processing: @processing,
            total_processed: @queue_stats[:total],
            avg_wait_time: wait_times.empty? ? 0.0 : wait_times.sum / wait_times.size,
            max_wait_time: wait_times.max || 0.0
          )
        end
      end
    end
  end
end
