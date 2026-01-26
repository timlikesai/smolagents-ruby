require_relative "future_base"
require_relative "../types/executors/batch_yield"

module Smolagents
  module Executors
    # Deferred tool execution with thread-local batch tracking.
    #
    # This is for orchestrated fiber execution (TrackedToolProxy).
    # For sandboxed Ractor execution, see RactorLazy::ToolFuture instead.
    #
    # TrackedToolProxy wraps real tools and returns these futures.
    # FutureBatch tracks pending calls via thread-local storage.
    # BatchYield is yielded when futures need resolution.
    #
    # @note Uses underscore-prefixed methods (see FutureBase for rationale)
    # @api private
    class ToolFuture < BasicObject
      include FutureBase

      attr_reader :tool_name, :arguments, :executor

      def initialize(tool_name:, arguments:, executor:)
        @tool_name = tool_name
        @arguments = arguments
        @executor = executor
        _init_future_state
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

      # Any method access triggers resolution
      def method_missing(method, ...)
        _ensure_resolved!
        @result.public_send(method, ...)
      end

      def respond_to_missing?(method, include_private = false)
        _ensure_resolved!
        @result.respond_to?(method, include_private)
      end

      def ==(other)
        _ensure_resolved!
        @result == other
      end

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

      def each(&)
        _ensure_resolved!
        @result.each(&)
      end

      def [](key)
        _ensure_resolved!
        @result[key]
      end

      private

      def _ensure_resolved!
        return if @resolved

        FutureBatch.resolve_all!
        ::Kernel.raise "ToolFuture not resolved after batch resolution" unless @resolved
        ::Kernel.raise @error if @error
      end
    end

    # Thread-local batch of pending futures.
    module FutureBatch
      class << self
        def current
          ::Thread.current[:smolagents_future_batch] ||= []
        end

        def register(future) = current << future

        def pending
          current.reject(&:_resolved?)
        end

        def clear!
          ::Thread.current[:smolagents_future_batch] = []
        end

        def resolve_all!
          batch = pending
          return if batch.empty?

          if FiberExecution.in_fiber?
            ::Fiber.yield(BatchYield.new(futures: batch))
          else
            batch.each(&:_execute!)
          end
        end
      end
    end
  end
end
