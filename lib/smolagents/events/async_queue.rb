module Smolagents
  module Events
    # Background thread queue for async event processing.
    #
    # Provides a singleton background worker that processes events without
    # blocking the main thread. Events are pushed to a Thread::Queue and
    # processed by a dedicated worker thread.
    #
    # @example Basic usage
    #   AsyncQueue.start
    #   AsyncQueue.push(event) { |e| handle(e) }
    #   AsyncQueue.shutdown(timeout: 5)
    #
    # @see Emitter For emitting events
    # @see Consumer For consuming events
    #
    module AsyncQueue
      class << self
        # Starts the background worker thread.
        # @return [Thread] The worker thread
        def start
          @mutex ||= Mutex.new
          @mutex.synchronize do
            return @worker if @worker&.alive?

            @queue = Thread::Queue.new
            @running = true
            @worker = Thread.new { process_loop }
          end
          @worker
        end

        # Pushes an event for async processing with its handler.
        # @param event [Object] The event to process
        # @yield [event] Block to execute with the event
        def push(event, &handler)
          start unless running?
          @queue&.push([event, handler])
        end

        # Shuts down the worker thread gracefully.
        # @param timeout [Numeric] Max seconds to wait for pending events
        # @return [Boolean] True if shutdown cleanly, false if timed out
        # rubocop:disable Naming/PredicateMethod -- shutdown is idiomatic
        def shutdown(timeout: 5)
          return true unless @worker&.alive?

          @mutex&.synchronize do
            @running = false
            @queue&.push(:shutdown)
          end

          result = @worker&.join(timeout)
          @worker = nil
          @queue = nil
          !result.nil?
        end
        # rubocop:enable Naming/PredicateMethod

        # Checks if the worker is running.
        # @return [Boolean]
        def running? = @worker&.alive? || false

        # Returns pending event count (for testing).
        # @return [Integer]
        def pending_count = @queue&.size || 0

        # Resets state (for testing).
        # @api private
        def reset!
          shutdown(timeout: 1)
          @mutex = nil
        end

        private

        def process_loop
          while @running || !@queue.empty?
            item = @queue.pop
            break if item == :shutdown

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
