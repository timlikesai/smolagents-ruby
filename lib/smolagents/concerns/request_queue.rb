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
      # Request wrapper for queue management (immutable Data class - Ruby 4.0 pattern).
      #
      # Wraps a generation request with metadata for tracking and scheduling.
      #
      # @!attribute [r] id
      #   @return [String] Unique request identifier (UUID)
      # @!attribute [r] priority
      #   @return [Symbol] Priority level (:high or :normal)
      # @!attribute [r] messages
      #   @return [Array<Hash>] Messages to send to the model (frozen)
      # @!attribute [r] kwargs
      #   @return [Hash] Additional generation parameters (frozen)
      # @!attribute [r] result_queue
      #   @return [Thread::Queue] Queue for returning results
      # @!attribute [r] queued_at
      #   @return [Time] When the request was enqueued
      QueuedRequest = Data.define(:id, :priority, :messages, :kwargs, :result_queue, :queued_at) do
        # Calculate how long the request has been waiting.
        #
        # @return [Float] Elapsed time in seconds since the request was queued
        #
        # @example
        #   request = QueuedRequest.new(id: "123", ..., queued_at: 10.seconds.ago)
        #   request.wait_time  # => ~10.0
        def wait_time
          Time.now - queued_at
        end

        # Check if this request has high priority.
        #
        # @return [Boolean] True if priority is :high
        def high_priority?
          priority == :high
        end
      end

      # Queue statistics (immutable).
      #
      # Snapshot of queue state at a point in time, for monitoring
      # and performance analysis.
      #
      # @!attribute [r] depth
      #   @return [Integer] Number of requests currently in queue
      # @!attribute [r] processing
      #   @return [Boolean] Whether a request is currently being processed
      # @!attribute [r] total_processed
      #   @return [Integer] Total requests successfully processed
      # @!attribute [r] avg_wait_time
      #   @return [Float] Average wait time of recent requests (seconds)
      # @!attribute [r] max_wait_time
      #   @return [Float] Maximum wait time of recent requests (seconds)
      QueueStats = Data.define(:depth, :processing, :total_processed, :avg_wait_time, :max_wait_time) do
        # Convert queue statistics to a Hash for serialization or logging.
        #
        # @return [Hash] Hash with :depth, :processing, :total_processed,
        #   :avg_wait_time (rounded to 2 decimals), :max_wait_time
        #
        # @example
        #   stats = model.queue_stats
        #   stats.to_h
        #   # => { depth: 2, processing: true, total_processed: 42, avg_wait_time: 1.23, max_wait_time: 5.67 }
        def to_h
          {
            depth:,
            processing:,
            total_processed:,
            avg_wait_time: avg_wait_time.round(2),
            max_wait_time: max_wait_time.round(2)
          }
        end
      end

      def self.extended(base)
        base.extend(Events::Emitter) unless base.singleton_class.include?(Events::Emitter)
        base.instance_variable_set(:@queue_enabled, false)
        base.instance_variable_set(:@queue_max_depth, nil)
        base.instance_variable_set(:@queue_stats, { total: 0, wait_times: [], mutex: Mutex.new })
        base.instance_variable_set(:@request_queue, nil)
        base.instance_variable_set(:@worker_thread, nil)
        base.instance_variable_set(:@processing, false)
      end

      # Enable request queueing
      #
      # @param max_depth [Integer, nil] Maximum queue depth (nil = unlimited)
      # @return [self]
      def enable_queue(max_depth: nil, **_ignored)
        return self if @queue_enabled

        @queue_enabled = true
        @queue_max_depth = max_depth

        # Single queue - priority handled by insertion order
        # Thread::Queue is the idiomatic Ruby 4.0 way - thread-safe by design
        @request_queue = Thread::Queue.new

        # Start worker thread that processes requests sequentially
        @worker_thread = Thread.new { process_queue_loop }
        @worker_thread.name = "RequestQueue-Worker-#{object_id}"

        self
      end

      # Disable request queueing and stop the worker thread
      #
      # @return [self]
      def disable_queue
        return self unless @queue_enabled

        @queue_enabled = false

        # Signal worker to stop by pushing nil (poison pill pattern)
        @request_queue&.push(nil)
        @worker_thread&.kill if @worker_thread&.alive?

        @request_queue = nil
        @worker_thread = nil

        self
      end

      # Check if queueing is enabled
      def queue_enabled?
        @queue_enabled
      end

      # Current number of requests waiting
      def queue_depth
        @request_queue&.size || 0
      end

      # Check if currently processing a request
      def processing?
        @processing
      end

      # Get queue statistics
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

      # Generate with queueing - requests are processed one at a time
      def queued_generate(messages, priority: :normal, **kwargs)
        return generate_without_queue(messages, **kwargs) unless @queue_enabled

        validate_queue_capacity!
        request = build_queued_request(messages, priority, kwargs)
        enqueue_request(request, priority)
        await_result(request.result_queue)
      end

      def validate_queue_capacity!
        return unless @queue_max_depth && queue_depth >= @queue_max_depth

        raise AgentError,
              "Queue full (#{queue_depth}/#{@queue_max_depth})"
      end

      def build_queued_request(messages, priority, kwargs)
        QueuedRequest.new(id: SecureRandom.uuid, priority:, messages: messages.freeze, kwargs: kwargs.freeze,
                          result_queue: Thread::Queue.new, queued_at: Time.now)
      end

      def enqueue_request(request, priority)
        priority == :high ? reorder_with_priority(request) : @request_queue.push(request)
      end

      def await_result(result_queue)
        result = result_queue.pop
        result.is_a?(Exception) ? raise(result) : result
      end

      # Clear all pending requests
      def clear_queue
        @request_queue&.clear
      end

      # Maximum iterations for worker loop (prevents runaway)
      MAX_QUEUE_ITERATIONS = 10_000

      private

      def reorder_with_priority(high_priority_request)
        # Atomic reorder: drain queue, insert high priority first, refill
        existing = []
        while @request_queue.size.positive?
          begin
            existing << @request_queue.pop(true)
          rescue ThreadError
            break
          end
        end

        @request_queue.push(high_priority_request)
        existing.each { |req| @request_queue.push(req) }
      end

      # Worker thread - waits for requests and processes them
      # Background worker threads waiting for work is OK (like Node.js thread pool)
      # The main event loop should never block - only background workers
      def process_queue_loop
        MAX_QUEUE_ITERATIONS.times do
          break if @request_queue.closed?

          # Blocking pop with nil check for poison pill shutdown
          request = @request_queue.pop
          break if request.nil? # Poison pill received

          process_request(request)
        end
      rescue StandardError => e
        warn "RequestQueue worker error: #{e.message}" if $DEBUG
      end

      def process_request(request)
        @processing = true

        @queue_stats[:mutex].synchronize do
          @queue_stats[:wait_times] << request.wait_time
          @queue_stats[:total] += 1
        end

        result = generate_without_queue(request.messages, **request.kwargs)
        request.result_queue.push(result)
      rescue StandardError => e
        request.result_queue.push(e)
      ensure
        @processing = false
      end

      def generate_without_queue(messages, **)
        if respond_to?(:original_generate, true)
          original_generate(messages, **)
        elsif respond_to?(:generate, true)
          method(:generate).super_method&.call(messages, **) || generate(messages, **)
        else
          raise NotImplementedError, "No generate method found"
        end
      end
    end
  end
end
