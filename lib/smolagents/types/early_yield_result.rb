module Smolagents
  module Types
    # Result from early yield execution.
    #
    # Contains the early result(s) that triggered yield, plus a callback
    # to collect remaining results later if needed.
    #
    # @!attribute [r] results
    #   @return [Array<Object>] Results available at yield time
    # @!attribute [r] early_result
    #   @return [Object, nil] The result that triggered early yield
    # @!attribute [r] pending_count
    #   @return [Integer] Number of tool calls still in progress
    # @!attribute [r] collector
    #   @return [Proc, nil] Lambda to collect remaining results
    EarlyYieldResult = Data.define(:results, :early_result, :pending_count, :collector) do
      # Check if this was an early yield (not all results collected).
      # @return [Boolean]
      def early? = pending_count.positive?

      # Check if all results are complete.
      # @return [Boolean]
      def complete? = pending_count.zero?

      # Collect remaining results (blocks until all complete).
      # Safe to call multiple times - returns cached results.
      # @return [Array<Object>] All results including late arrivals
      def collect_remaining
        return results if complete?

        collector&.call || results
      end
    end
  end
end
