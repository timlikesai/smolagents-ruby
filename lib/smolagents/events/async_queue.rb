module Smolagents
  module Events
    # Global singleton for async event processing.
    #
    # Provides a background worker thread that processes events without
    # blocking the main thread. Events are pushed to a Thread::Queue and
    # processed by a dedicated worker.
    #
    # @example Basic usage
    #   AsyncQueue.start
    #   AsyncQueue.push(event) { |e| handle(e) }
    #   AsyncQueue.shutdown(timeout: 5)
    #
    # @see Emitter For emitting events
    # @see Consumer For consuming events
    module AsyncQueue
      # Shutdown timeout in seconds.
      SHUTDOWN_TIMEOUT = 5

      # Synchronization helper for drain operations.
      # @api private
      class DrainSignal
        def initialize
          @mutex = Mutex.new
          @cv = ConditionVariable.new
          @done = false
        end

        def complete!
          @mutex.synchronize do
            @done = true
            @cv.signal
          end
        end

        def wait(timeout)
          @mutex.synchronize do
            @cv.wait(@mutex, timeout) unless @done
            @done
          end
        end
      end

      class << self
        # Starts the background worker thread.
        # @return [Thread] The worker thread
        def start
          @mutex ||= Mutex.new
          @mutex.synchronize do
            return @worker if @worker&.alive?

            @queue = Thread::Queue.new
            @worker = Thread.new { process_loop }
            @worker.name = "AsyncQueue-Worker"
          end
          @worker
        end

        # Pushes an event for async processing with its handler.
        # @param event [Object] The event to process
        # @yield [event] Block to execute with the event
        def push(event, &handler)
          start unless running?
          @queue&.push([event, handler]) unless @queue&.closed?
        end

        # Shuts down the worker thread gracefully.
        # @param timeout [Numeric] Max seconds to wait for pending events
        # @return [Boolean] True if shutdown cleanly, false if timed out
        def shutdown(timeout: SHUTDOWN_TIMEOUT)
          return true unless @worker&.alive?

          @queue&.close
          graceful = join_worker(timeout)
          @worker = nil
          @queue = nil
          graceful
        end

        # Checks if the worker is running.
        # @return [Boolean]
        def running? = @worker&.alive? || false

        # Returns pending event count (for testing).
        # @return [Integer]
        def pending_count = @queue&.size || 0

        # Wait for all pending events to be processed.
        #
        # @param timeout [Numeric] Max seconds to wait (default: 5)
        # @return [Boolean] True if drained, false if timed out
        def drain(timeout: SHUTDOWN_TIMEOUT)
          return true unless running?

          signal = DrainSignal.new
          push(:drain_marker) { signal.complete! }
          signal.wait(timeout)
        end

        # Resets state (for testing).
        # @api private
        def reset!
          shutdown(timeout: 1)
          @mutex = nil
        end

        private

        # rubocop:disable Naming/PredicateMethod -- returns success status, not a predicate
        def join_worker(timeout)
          result = @worker&.join(timeout)
          @worker&.kill if @worker&.alive?
          !result.nil?
        end
        # rubocop:enable Naming/PredicateMethod

        def process_loop
          loop do
            item = @queue.pop
            break if item.nil? # Queue closed and empty

            event, handler = item
            safe_execute(event, handler)
          end
        end

        def safe_execute(event, handler)
          handler&.call(event)
        rescue StandardError => e
          warn "AsyncQueue error processing #{event.class}: #{e.message}"
        end
      end
    end
  end
end
