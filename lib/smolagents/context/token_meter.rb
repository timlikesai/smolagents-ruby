# Active budget tracker during context assembly.
#
# Immutable token meter that tracks consumption against a budget.
# Provides predicates for budget status and headroom calculations.
#
# @example Basic usage
#   meter = TokenMeter.new(budget: 1000)
#   meter = meter.add(500)
#   meter.remaining      #=> 500
#   meter.usage_percent  #=> 0.5
#   meter.warning?       #=> false
#   meter = meter.add(400)
#   meter.warning?       #=> true (>= 80%)
module Smolagents
  module Context
    TokenMeter = Data.define(:budget, :used, :warn_at, :fail_at) do
      # Creates a new token meter with the given budget.
      # @param budget [Integer] Total token budget
      # @param used [Integer] Tokens already used (default: 0)
      # @param warn_at [Float] Threshold for warning (default: 0.8 = 80%)
      # @param fail_at [Float] Threshold for failure (default: 1.0 = 100%)
      # @return [TokenMeter]
      def initialize(budget:, used: 0, warn_at: 0.8, fail_at: 1.0) = super

      # Adds tokens to the meter, returning a new meter.
      # @param tokens [Integer] Number of tokens to add
      # @return [TokenMeter] New meter with updated usage
      def add(tokens)
        with(used: used + tokens)
      end

      # Returns remaining budget.
      # @return [Integer] Tokens remaining
      def remaining = budget - used

      # Returns usage as a percentage (0.0 to 1.0+).
      # @return [Float] Usage percentage
      def usage_percent = budget.positive? ? used.to_f / budget : 0.0

      # Checks if usage exceeds budget.
      # @return [Boolean]
      def over_budget? = used > budget

      # Checks if usage is at or above warning threshold.
      # @return [Boolean]
      def warning? = usage_percent >= warn_at

      # Returns available headroom (non-negative).
      # @return [Integer] Maximum tokens that can still be added
      def headroom = [remaining, 0].max

      # Checks if the given tokens can fit within remaining budget.
      # @param tokens [Integer] Number of tokens to check
      # @return [Boolean]
      def can_fit?(tokens) = tokens <= remaining
    end
  end
end
