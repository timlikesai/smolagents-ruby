module Smolagents
  module Concerns
    # Evented timeout wrapper for model.generate() calls.
    #
    # Protects against hung model calls (common with local GPU inference)
    # using a worker thread + Queue#pop(timeout:) pattern. No sleep,
    # no Timeout.timeout — fully evented, instant wakeup on completion.
    #
    # Configure via `.generation_timeout(seconds)` on AgentBuilder.
    # Default: nil (no timeout). Set to positive number to enable.
    #
    # @example
    #   agent = Smolagents.agent.model { m }.generation_timeout(120).build
    #
    # @see CodeGeneration For the primary call site
    module GenerationTimeout
      DEFAULT_GENERATION_TIMEOUT = nil

      private

      # Initialize generation timeout.
      # @param timeout [Numeric, nil] Timeout in seconds (nil = disabled)
      def initialize_generation_timeout(timeout: DEFAULT_GENERATION_TIMEOUT)
        @generation_timeout = timeout
      end

      # Wrap a model.generate call with evented timeout.
      #
      # Uses a worker thread + Queue for instant wakeup (no polling).
      # The worker runs the generation; Queue#pop(timeout:) blocks
      # until either the worker finishes or the timeout expires.
      #
      # @param context [Symbol] Call site identifier for error context
      # @yield The model.generate call
      # @return [Object] Generation result
      # @raise [Errors::TimeoutError] If generation exceeds timeout
      def with_generation_timeout(context: :step, &block)
        return yield unless @generation_timeout&.positive?

        execute_with_timeout(context, block)
      end

      def execute_with_timeout(context, task)
        result_queue = Queue.new

        worker = Thread.new do
          result_queue.push([:ok, task.call])
        rescue StandardError => e
          result_queue.push([:error, e])
        end

        handle_timeout_result(result_queue, worker, context)
      end

      def handle_timeout_result(result_queue, worker, context)
        entry = result_queue.pop(timeout: @generation_timeout)
        return raise_generation_timeout(worker, context) unless entry

        worker.join
        status, payload = entry
        raise payload if status == :error

        payload
      end

      def raise_generation_timeout(worker, context)
        worker.kill
        raise Errors::TimeoutError.new(
          "Model generation timed out after #{@generation_timeout}s",
          operation: context, duration: @generation_timeout
        )
      end
    end
  end
end
