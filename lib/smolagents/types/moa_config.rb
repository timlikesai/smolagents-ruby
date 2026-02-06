module Smolagents
  module Types
    # Configuration for Mixture-of-Agents (MoA) pattern.
    #
    # Strategies: :voting (highest confidence), :synthesis (combine), :rank_fusion (weighted)
    #
    # @see Proposal, AggregationResult
    MoAConfig = Data.define(
      :proposer_count,        # Integer: number of proposers (2-20)
      :aggregation_strategy,  # Symbol: :voting, :synthesis, or :rank_fusion
      :timeout_per_proposer,  # Integer: seconds per proposer
      :parallel,              # Boolean: run proposers in parallel
      :enabled                # Boolean: whether MoA is active
    ) do
      # Validation constants
      MIN_PROPOSERS = 2
      MAX_PROPOSERS = 20

      # @return [MoAConfig] Default: 3 proposers, voting, parallel
      def self.default
        new(
          proposer_count: 3,
          aggregation_strategy: :voting,
          timeout_per_proposer: 30,
          parallel: true,
          enabled: true
        )
      end

      # @return [MoAConfig] Disabled configuration
      def self.disabled
        new(
          proposer_count: 3,
          aggregation_strategy: :voting,
          timeout_per_proposer: 30,
          parallel: true,
          enabled: false
        )
      end

      # @return [MoAConfig] Fast: 3 proposers, voting
      def self.fast
        new(
          proposer_count: 3,
          aggregation_strategy: :voting,
          timeout_per_proposer: 30,
          parallel: true,
          enabled: true
        )
      end

      # @return [MoAConfig] Thorough: 5 proposers, synthesis
      def self.thorough
        new(
          proposer_count: 5,
          aggregation_strategy: :synthesis,
          timeout_per_proposer: 60,
          parallel: true,
          enabled: true
        )
      end

      # Creates a validated custom configuration.
      # @raise [ArgumentError] If validation fails
      def self.create(proposer_count: 3, aggregation_strategy: :voting, timeout_per_proposer: 30,
                      parallel: true, enabled: true)
        validate_proposer_count!(proposer_count)
        validate_strategy!(aggregation_strategy)

        new(proposer_count:, aggregation_strategy:, timeout_per_proposer:, parallel:, enabled:)
      end

      class << self
        private

        def validate_proposer_count!(count)
          return if count.between?(MIN_PROPOSERS, MAX_PROPOSERS)

          raise ArgumentError, "proposer_count must be between #{MIN_PROPOSERS} and #{MAX_PROPOSERS}, got #{count}"
        end

        def validate_strategy!(strategy)
          return if AGGREGATION_STRATEGIES.include?(strategy)

          raise ArgumentError,
                "aggregation_strategy must be one of #{AGGREGATION_STRATEGIES.inspect}, got #{strategy.inspect}"
        end
      end

      include TypeSupport::StatePredicates

      state_predicates :aggregation_strategy, voting: :voting, synthesis: :synthesis, rank_fusion: :rank_fusion

      def enabled? = enabled
      def disabled? = !enabled
      def parallel? = parallel
      def total_timeout = proposer_count * timeout_per_proposer
    end
  end
end
