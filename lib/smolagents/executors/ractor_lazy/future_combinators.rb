module Smolagents
  module Executors
    module RactorLazy
      # ES6 Promise-inspired combinators for ToolFuture.
      #
      # Provides parallel execution patterns:
      # - all: Wait for all, fail fast on any error
      # - race: Return first resolved (success or error)
      # - any: Return first success, fail only if all fail
      # - all_settled: Wait for all, collect results + errors
      #
      # @note Uses underscore-prefixed methods (see FutureBase for rationale)
      # @api private
      module FutureCombinators
        # Wait for all futures to resolve. Fail fast on first error.
        # @param futures [Array<ToolFuture>] futures to resolve
        # @return [Array] array of resolved values
        # @raise [StandardError] first error encountered
        def all(futures)
          futures = ::Kernel.Array(futures)
          return [] if futures.empty?

          _ensure_all_resolved!(futures)
          futures.each { |f| ::Kernel.raise f._error if f._error }
          futures.map(&:_result)
        end

        # Return first future to resolve (success or error).
        # @param futures [Array<ToolFuture>] futures to race
        # @return [Object] first resolved value
        # @raise [StandardError] if first resolved is an error
        def race(futures)
          futures = ::Kernel.Array(futures)
          return nil if futures.empty?

          _ensure_any_resolved!(futures)
          winner = futures.find(&:_resolved?)
          ::Kernel.raise winner._error if winner._error
          winner._result
        end

        # Return first successful future. Fail only if ALL fail.
        # @param futures [Array<ToolFuture>] futures to try
        # @return [Object] first successful value
        # @raise [AggregateError] if all futures fail
        def any(futures)
          futures = ::Kernel.Array(futures)
          ::Kernel.raise AggregateError.new("No futures provided", []) if futures.empty?

          _ensure_all_resolved!(futures)
          success = futures.find { |f| f._resolved? && !f._error }
          return success._result if success

          ::Kernel.raise AggregateError.new("All futures failed", futures.map(&:_error))
        end

        # Wait for all futures, collecting both successes and failures.
        # @param futures [Array<ToolFuture>] futures to settle
        # @return [Array<Hash>] array of {status:, value:} or {status:, error:}
        def all_settled(futures)
          futures = ::Kernel.Array(futures)
          return [] if futures.empty?

          _ensure_all_resolved!(futures)
          futures.map do |f|
            f._error ? { status: :rejected, error: f._error } : { status: :fulfilled, value: f._result }
          end
        end

        private

        def _ensure_all_resolved!(futures)
          pending = futures.select(&:_pending?)
          return if pending.empty?

          ::Fiber.yield({ type: :batch, futures: pending })
          ::Kernel.raise "Futures not resolved after batch" unless futures.all?(&:_resolved?)
        end

        def _ensure_any_resolved!(futures)
          loop do
            return if futures.any?(&:_resolved?)

            pending = futures.select(&:_pending?)
            break if pending.empty?

            ::Fiber.yield({ type: :batch, futures: pending })
          end
        end
      end

      # Error containing multiple errors (like AggregateError in JS).
      class AggregateError < ::StandardError
        attr_reader :errors

        def initialize(message, errors)
          @errors = errors
          super("#{message}: #{errors.map(&:to_s).join(", ")}")
        end
      end
    end
  end
end
