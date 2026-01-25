module Smolagents
  module Executors
    # Shared resolution logic for ToolFuture implementations.
    #
    # Provides core state management for lazy-evaluated futures:
    # - Resolution: _resolve!, _reject!
    # - State queries: _resolved?, _pending?, _result, _error
    #
    # Used by both outer (Executors::ToolFuture) and inner (RactorLazy::ToolFuture).
    # Each implementation provides its own initialize and _ensure_resolved!.
    #
    module FutureBase
      # Injects the resolved result.
      def _resolve!(value)
        @result = value
        @resolved = true
      end

      # Injects an error (marks as resolved but failed).
      def _reject!(error)
        @error = error
        @resolved = true
      end

      def _resolved? = @resolved
      def _pending? = !@resolved
      def _result = @result
      def _error = @error

      # True for any ToolFuture instance (duck-typing support).
      def _future? = true

      protected

      # Initialize resolution state. Call from subclass initialize.
      def _init_future_state
        @resolved = false
        @result = nil
        @error = nil
      end
    end
  end
end
