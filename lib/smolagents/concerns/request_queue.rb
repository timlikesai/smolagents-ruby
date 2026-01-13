module Smolagents
  module Concerns
    # Adds request queueing for models that can only handle one request at a time.
    #
    # Uses Ruby 4.0's Thread::Queue for thread-safe producer-consumer pattern.
    # This is the idiomatic Ruby approach - Thread::Queue handles all synchronization
    # internally, making the code simpler and more robust.
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
    #   model.queued_generate(messages, priority: :high)  # Processed before normal priority
    #
    module RequestQueue
      # Request wrapper for queue management (immutable Data class - Ruby 4.0 pattern)
      QueuedRequest = Data.define(:id, :priority, :messages, :kwargs, :result_queue, :queued_at) do
        def wait_time
          Time.now - queued_at
        end

        def high_priority?
          priority == :high
        end
      end

      # Queue statistics (immutable)
      QueueStats = Data.define(:depth, :processing, :total_processed, :avg_wait_time, :max_wait_time) do
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
        base.instance_variable_set(:@queue_enabled, false)
        base.instance_variable_set(:@queue_max_depth, nil)
        base.instance_variable_set(:@queue_callbacks, { complete: [] })
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

      # Register callback for request completion
      def on_queue_complete(&block)
        @queue_callbacks[:complete] << block
        self
      end

      # Generate with queueing - requests are processed one at a time
      def queued_generate(messages, priority: :normal, **kwargs)
        return generate_without_queue(messages, **kwargs) unless @queue_enabled

        raise AgentError, "Queue full (#{queue_depth}/#{@queue_max_depth})" if @queue_max_depth && queue_depth >= @queue_max_depth

        result_queue = Thread::Queue.new

        request = QueuedRequest.new(
          id: SecureRandom.uuid,
          priority:,
          messages: messages.freeze,
          kwargs: kwargs.freeze,
          result_queue:,
          queued_at: Time.now
        )

        # Push to queue - high priority goes to front via unshift workaround
        if priority == :high
          # For high priority, we need to reorder - drain, insert at front, refill
          reorder_with_priority(request)
        else
          @request_queue.push(request)
        end

        # Wait for result (blocks until worker processes request)
        result = result_queue.pop

        case result
        when Exception
          raise result
        else
          result
        end
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
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          @queue_stats[:mutex].synchronize do
            @queue_stats[:wait_times] << request.wait_time
            @queue_stats[:total] += 1
          end

          result = generate_without_queue(request.messages, **request.kwargs)
          request.result_queue.push(result)

          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          notify_complete(request, duration)
        rescue StandardError => e
          request.result_queue.push(e)
        ensure
          @processing = false
        end
      end

      def notify_complete(request, duration)
        @queue_callbacks[:complete].each { |cb| cb.call(request, duration) }
      rescue StandardError
        # Ignore callback errors
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
