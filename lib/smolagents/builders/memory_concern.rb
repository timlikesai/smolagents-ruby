module Smolagents
  module Builders
    # Memory configuration DSL methods for AgentBuilder.
    #
    # Extracted to keep builder focused on composition.
    module MemoryConcern
      include Support::FlexibleInput

      # Configure memory management.
      #
      # @overload memory
      #   Use default config (no budget, :full strategy)
      #
      # @overload memory(budget_or_strategy)
      #   Set budget (Integer) or strategy (Symbol) directly
      #   @param budget_or_strategy [Integer, Symbol] Budget or strategy
      #
      # @overload memory(budget:, strategy:, preserve_recent:)
      #   Full configuration with keywords
      #
      # @param budget [Integer, nil] Token budget for memory
      # @param strategy [Symbol, nil] Memory strategy (:full, :mask, :summarize, :hybrid)
      # @param preserve_recent [Integer, nil] Number of recent steps to preserve
      # @return [AgentBuilder]
      #
      # @example Enable memory with defaults
      #   builder = Smolagents.agent.memory
      #
      # @example Set budget directly (Integer)
      #   builder = Smolagents.agent.memory(100_000)
      #   builder.config[:memory_config].budget  #=> 100000
      #
      # @example Set strategy directly (Symbol)
      #   builder = Smolagents.agent.memory(:mask)
      #   builder.config[:memory_config].strategy  #=> :mask
      #
      # @example Full configuration (keywords)
      #   builder = Smolagents.agent.memory(budget: 50_000, strategy: :hybrid)
      def memory(value = UNSET, budget: nil, strategy: nil, preserve_recent: nil)
        check_frozen!
        resolved_budget, resolved_strategy = dispatch_by_type(
          value, name: "memory", Integer => budget, Symbol => strategy
        )
        with_config(memory_config: build_memory_config(resolved_budget, resolved_strategy, preserve_recent))
      end

      private

      # Build a MemoryConfig from provided parameters.
      def build_memory_config(budget, strategy, preserve_recent)
        return Types::MemoryConfig.default if budget.nil? && strategy.nil?

        Types::MemoryConfig.new(
          budget:,
          strategy: strategy || (budget ? :mask : :full),
          preserve_recent: preserve_recent || 5,
          mask_placeholder: "[Previous observation truncated]",
          compression_threshold: 0.75
        )
      end
    end
  end
end
