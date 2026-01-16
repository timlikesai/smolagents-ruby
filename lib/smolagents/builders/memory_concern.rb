module Smolagents
  module Builders
    # Memory configuration DSL methods for AgentBuilder.
    #
    # Extracted to keep builder focused on composition.
    module MemoryConcern
      # Configure memory management.
      #
      # @overload memory
      #   Use default config (no budget, :full strategy)
      # @overload memory(budget:)
      #   Set token budget with mask strategy
      # @overload memory(budget:, strategy:, preserve_recent:)
      #   Full configuration
      #
      # @param budget [Integer, nil] Token budget for memory
      # @param strategy [Symbol, nil] Memory strategy (:full, :mask, :summarize, :hybrid)
      # @param preserve_recent [Integer, nil] Number of recent steps to preserve
      # @return [AgentBuilder]
      #
      # @example Use defaults
      #   .memory
      #
      # @example Set budget with mask strategy
      #   .memory(budget: 100_000)
      #
      # @example Full configuration
      #   .memory(budget: 100_000, strategy: :hybrid, preserve_recent: 5)
      def memory(budget: nil, strategy: nil, preserve_recent: nil)
        check_frozen!
        with_config(memory_config: build_memory_config(budget, strategy, preserve_recent))
      end

      private

      def build_memory_config(budget, strategy, preserve_recent)
        return Types::MemoryConfig.default if budget.nil? && strategy.nil?

        Types::MemoryConfig.new(
          budget:,
          strategy: strategy || (budget ? :mask : :full),
          preserve_recent: preserve_recent || 5,
          mask_placeholder: "[Previous observation truncated]"
        )
      end
    end
  end
end
