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
      # @example Enable memory with defaults
      #   builder = Smolagents.agent.memory
      #   builder.config[:memory_config].nil?
      #   #=> false
      #
      # @example Set budget with mask strategy
      #   builder = Smolagents.agent.memory(budget: 100_000)
      #   builder.config[:memory_config].budget
      #   #=> 100000
      #
      # @example Full configuration
      #   builder = Smolagents.agent.memory(budget: 50_000, strategy: :hybrid)
      #   builder.config[:memory_config].strategy
      #   #=> :hybrid
      def memory(budget: nil, strategy: nil, preserve_recent: nil)
        check_frozen!
        with_config(memory_config: build_memory_config(budget, strategy, preserve_recent))
      end

      private

      # Build a MemoryConfig from provided parameters.
      # @param budget [Integer, nil] Token budget
      # @param strategy [Symbol, nil] Memory strategy
      # @param preserve_recent [Integer, nil] Number of recent steps to preserve
      # @return [Types::MemoryConfig]
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
