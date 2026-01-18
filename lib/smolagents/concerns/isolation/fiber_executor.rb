module Smolagents
  module Concerns
    module Isolation
      # Fiber-based executor for cooperative resource isolation.
      #
      # Executes blocks using Fiber scheduling for cooperative multitasking.
      # Useful for event-driven architectures where blocking is undesirable.
      # Currently delegates to ThreadExecutor but could be extended for
      # cooperative yielding in long-running operations.
      #
      # @example Basic execution
      #   limits = Types::Isolation::ResourceLimits.default
      #   result = FiberExecutor.execute(limits:) { fetch_data }
      #   result.success?  # => true if within limits
      #
      # @see Types::Isolation::IsolationResult For result types
      # @see ThreadExecutor For thread-based isolation
      module FiberExecutor
        # Executes a block with timeout using Fiber scheduling.
        #
        # @param limits [Types::Isolation::ResourceLimits] Resource limits
        # @yield Block to execute
        # @return [Types::Isolation::IsolationResult] Execution result
        def self.execute(limits:, &)
          # Fiber mode currently uses the same mechanism as ThreadExecutor.
          # Future enhancements could add cooperative yielding for long ops.
          ThreadExecutor.execute(limits:, &)
        end
      end
    end
  end
end
