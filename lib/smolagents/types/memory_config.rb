module Smolagents
  module Types
    # Configuration for memory management and context window optimization.
    #
    # MemoryConfig controls how AgentMemory handles token budgets and message
    # truncation. It supports multiple strategies for managing long conversations
    # that exceed context window limits.
    #
    # == Strategies
    #
    # - `:full` - Keep all messages, no truncation (default)
    # - `:mask` - Replace old observations with placeholder text
    # - `:summarize` - Use LLM to summarize old context
    # - `:hybrid` - Combine masking with summarization
    #
    # @example Using default (unlimited) config
    #   config = MemoryConfig.default
    #   config.budget?  # => false
    #
    # @example Creating a masked config with budget
    #   config = MemoryConfig.masked(budget: 8000, preserve_recent: 5)
    #   config.mask?  # => true
    #   config.preserve_recent  # => 5
    #
    # @see Runtime::AgentMemory Uses this to manage context
    MemoryConfig = Data.define(:budget, :strategy, :preserve_recent, :mask_placeholder,
                               :compression_threshold) do
      extend TypeSupport::FactoryBuilder
      include TypeSupport::StatePredicates

      factory :default, budget: nil, strategy: :full, preserve_recent: 3,
                        mask_placeholder: "[Previous observation truncated]",
                        compression_threshold: 0.75

      state_predicates :strategy, full: :full, mask: :mask, summarize: :summarize, hybrid: :hybrid

      # Creates a config that masks old observations.
      #
      # @param budget [Integer] Token budget for memory
      # @param preserve_recent [Integer] Number of recent steps to preserve (default: 5)
      # @return [MemoryConfig] Config with mask strategy
      def self.masked(budget:, preserve_recent: 5)
        new(budget:, strategy: :mask, preserve_recent:,
            mask_placeholder: "[Previous observation truncated]", compression_threshold: 0.75)
      end

      # Creates a config that summarizes old context.
      #
      # @param budget [Integer] Token budget for memory
      # @param threshold [Float] Usage fraction to trigger compression (default: 0.75)
      # @return [MemoryConfig] Config with summarize strategy
      def self.summarized(budget:, threshold: 0.75)
        new(budget:, strategy: :summarize, preserve_recent: 3,
            mask_placeholder: "[Previous observation truncated]", compression_threshold: threshold)
      end

      # Checks if a token budget is set.
      # @return [Boolean] True if budget is present
      def budget? = !budget.nil?
    end
  end
end
