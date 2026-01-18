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
        extend_modules(base)
        initialize_state(base)
      end

      def self.extend_modules(base)
        base.extend(Events::Emitter) unless base.singleton_class.include?(Events::Emitter)
        [Operations, Worker, DeadLetter].each { |mod| base.extend(mod) }
      end

      def self.initialize_state(base)
        initial_state.each { |name, value| base.instance_variable_set(:"@#{name}", value) }
      end

      def self.initial_state
        { queue_enabled: false, queue_max_depth: nil, request_queue: nil, worker_thread: nil,
          processing: false, dlq_enabled: false, queue_stats: { total: 0, wait_times: [], mutex: Mutex.new } }
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
        @queue_stats[:mutex].synchronize { build_queue_stats }
      end

      private

      def build_queue_stats
        wait_times = @queue_stats[:wait_times].last(100)
        QueueStats.new(
          depth: queue_depth, processing: @processing, total_processed: @queue_stats[:total],
          avg_wait_time: average_wait_time(wait_times), max_wait_time: wait_times.max || 0.0
        )
      end

      def average_wait_time(times) = times.empty? ? 0.0 : times.sum / times.size
    end
  end
end
