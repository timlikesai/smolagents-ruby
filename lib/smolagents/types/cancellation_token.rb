module Smolagents
  module Types
    # Thread-safe cancellation token for agent execution.
    #
    # Allows external threads to signal cancellation while the agent
    # loop checks at step boundaries.
    #
    # @example
    #   token = CancellationToken.new
    #   Thread.new { token.cancel! }
    #   token.cancelled?  #=> true (eventually)
    class CancellationToken
      def initialize
        @mutex = Mutex.new
        @cancelled = false
      end

      # Signal cancellation from any thread.
      # @return [void]
      def cancel!
        @mutex.synchronize { @cancelled = true }
      end

      # Check if cancelled (thread-safe).
      # @return [Boolean]
      def cancelled?
        @mutex.synchronize { @cancelled }
      end

      # Reset token (for reuse).
      # @return [void]
      def reset!
        @mutex.synchronize { @cancelled = false }
      end
    end
  end
end
