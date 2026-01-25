module Smolagents
  module Executors
    # Deferred tool execution with thread-local batch tracking.
    #
    # This is for orchestrated fiber execution (TrackedToolProxy).
    # For sandboxed Ractor execution, see RactorLazy::ToolFuture instead.
    #
    # == Architecture Position
    #
    # This file provides the "outer" future system used by the agent orchestrator:
    # - TrackedToolProxy wraps real tools and returns these futures
    # - FutureBatch tracks pending calls via thread-local storage
    # - BatchYield is yielded when futures need resolution
    #
    # RactorLazy::ToolFuture is the "inner" system for sandboxed code:
    # - Runs inside Ractor isolation
    # - Uses Fiber.yield with batch arrays (not thread-local)
    # - Has ES6 Promise combinators (all, race, any, all_settled)
    #
    # == How It Works
    #
    #   # Agent code (via TrackedToolProxy):
    #   ruby = search(query: "Ruby")      # Returns ToolFuture, registers with FutureBatch
    #   python = search(query: "Python")  # Returns ToolFuture, registers with FutureBatch
    #
    #   # Access triggers batch resolution:
    #   ruby.first['title']  # Yields BatchYield to orchestrator
    #                        # Orchestrator runs both tools in parallel
    #                        # Resumes fiber with results
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
