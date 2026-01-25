require_relative "../future_base"
require_relative "future_combinators"
require_relative "future_identity"
require_relative "future_operators"

module Smolagents
  module Executors
    module RactorLazy
      # Lazy tool proxy for sandboxed Ractor code execution.
      #
      # For sandboxed agent code (not orchestration - see Executors::ToolFuture).
      # Uses instance @batch (Ractor-safe) + Fiber.yield for resolution.
      #
      # Combinators: Future.all, Future.race, Future.any, Future.all_settled
      #
      class ToolFuture < BasicObject
        include FutureBase
        extend FutureCombinators
        include FutureIdentity
        include FutureOperators

        attr_reader :tool_name, :args, :kwargs

        def initialize(tool_name, args, kwargs, batch)
          @tool_name = tool_name
          @args = args
          @kwargs = kwargs
          @batch = batch
          _init_future_state
          @cancelled = false
          @timeout = @timeout_at = nil
          batch << self
        end

        # Cancellation (inner-only feature)
        def _cancelled? = @cancelled == true

        def _cancel!(reason = "Cancelled")
          return if @resolved

          @cancelled = true
          _reject!(reason)
        end

        # Timeout (inner-only feature)
        def _with_timeout(seconds)
          @timeout = seconds
          @timeout_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + seconds
          self
        end

        def _timeout = @timeout
        def _timeout_at = @timeout_at
        def _timed_out? = @timeout_at && ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) > @timeout_at

        def inspect
          return "#<Future:cancelled #{@tool_name}>" if @cancelled
          return "#<Future:pending #{@tool_name}>" unless @resolved

          "#<Future:resolved #{@tool_name} => #{@result.inspect[0, 50]}>"
        end

        private

        def _ensure_resolved!
          ::Kernel.raise @error if @cancelled
          return if @resolved

          _check_timeout!
          pending = @batch.select(&:_pending?)
          ::Fiber.yield({ type: :batch, futures: pending })

          _check_timeout!
          ::Kernel.raise "Future not resolved after batch" unless @resolved
          ::Kernel.raise @error if @error
        end

        def _check_timeout!
          return unless _timed_out?

          @error = "Future timed out after #{@timeout}s"
          @resolved = true
          ::Kernel.raise @error
        end
      end
    end
  end
end
