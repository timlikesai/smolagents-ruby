module Smolagents
  module Executors
    # Lazy-evaluated tool result with automatic parallel batching.
    #
    # When agent code calls a tool, it gets a ToolFuture immediately.
    # The actual tool execution is deferred until the result is accessed.
    # Multiple pending futures are batched and run in parallel.
    #
    # == How It Works
    #
    #   # Agent code:
    #   ruby = search(query: "Ruby")      # Instant - returns ToolFuture
    #   python = search(query: "Python")  # Instant - returns ToolFuture
    #
    #   # Access triggers resolution:
    #   ruby.first['title']  # NOW both futures resolve in parallel!
    #
    # == The Magic
    #
    # 1. Tool calls register futures with FutureBatch (thread-local)
    # 2. Any method call on a future triggers batch resolution
    # 3. Orchestrator receives all pending futures, runs in parallel
    # 4. Results are injected back, code continues
    #
    # This gives agents automatic parallelization with zero awareness.
    #
    class ToolFuture < BasicObject
      attr_reader :tool_name, :arguments, :executor

      def initialize(tool_name:, arguments:, executor:)
        @tool_name = tool_name
        @arguments = arguments
        @executor = executor # Lambda that actually runs the tool
        @resolved = false
        @result = nil
        @error = nil

        # Register with the current batch
        FutureBatch.register(self)
      end

      # Executes the tool (called by orchestrator during batch resolution)
      def _execute!
        return @result if @resolved

        @result = @executor.call
        @resolved = true
        @result
      rescue ::StandardError => e
        @error = e
        @resolved = true
        ::Kernel.raise e
      end

      # Injects the resolved result (called by orchestrator after parallel execution)
      def _resolve!(result)
        @result = result
        @resolved = true
      end

      # Injects an error (called by orchestrator if tool failed)
      def _reject!(error)
        @error = error
        @resolved = true
      end

      def _resolved? = @resolved
      def _result = @result
      def _error = @error

      # Any method access triggers resolution
      def method_missing(method, ...)
        _ensure_resolved!
        @result.public_send(method, ...)
      end

      def respond_to_missing?(method, include_private = false)
        _ensure_resolved!
        @result.respond_to?(method, include_private)
      end

      # Comparison delegates to resolved value
      def ==(other)
        _ensure_resolved!
        @result == other
      end

      # Explicit conversions trigger resolution
      def to_s
        _ensure_resolved!
        @result.to_s
      end

      def to_a
        _ensure_resolved!
        @result.to_a
      end

      def to_h
        _ensure_resolved!
        @result.to_h
      end

      def inspect
        return "#<ToolFuture:pending #{@tool_name}(#{@arguments.inspect})>" unless @resolved

        "#<ToolFuture:resolved #{@tool_name} => #{@result.inspect[0, 50]}>"
      end

      # Iteration triggers resolution
      def each(&)
        _ensure_resolved!
        @result.each(&)
      end

      # Indexing triggers resolution
      def [](key)
        _ensure_resolved!
        @result[key]
      end

      private

      def _ensure_resolved!
        return if @resolved

        # Trigger batch resolution - this yields to orchestrator
        FutureBatch.resolve_all!

        # After resume, we should be resolved
        ::Kernel.raise "ToolFuture not resolved after batch resolution" unless @resolved
        ::Kernel.raise @error if @error
      end
    end

    # Thread-local batch of pending futures.
    #
    # Collects futures until resolution is triggered, then yields
    # them all to the orchestrator for parallel execution.
    #
    module FutureBatch
      class << self
        def current
          ::Thread.current[:smolagents_future_batch] ||= []
        end

        def register(future)
          current << future
        end

        def pending
          current.reject(&:_resolved?)
        end

        def clear!
          ::Thread.current[:smolagents_future_batch] = []
        end

        # Resolves all pending futures.
        #
        # In Fiber context: yields BatchYield for orchestrator to handle
        # Outside Fiber context: executes tools synchronously
        #
        def resolve_all!
          batch = pending
          return if batch.empty?

          if FiberExecution.in_fiber?
            # Inside fiber - yield to orchestrator for potential parallel execution
            ::Fiber.yield(BatchYield.new(futures: batch))
          else
            # Outside fiber - execute synchronously
            batch.each(&:_execute!)
          end
        end
      end
    end

    # What gets yielded when futures need resolution.
    #
    # Contains all pending futures for parallel execution.
    #
    BatchYield = Data.define(:futures) do
      def tool_names = futures.map(&:tool_name)
      def size = futures.size

      def to_s = "BatchYield[#{size} tools: #{tool_names.join(", ")}]"
    end
  end
end
