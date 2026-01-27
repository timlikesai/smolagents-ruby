module Smolagents
  module Builders
    # Build methods for MixtureOfAgentsBuilder.
    #
    # Extracted from the main builder to keep module size under 100 lines.
    module MoABuildConcern
      private

      def validate_strategy!(name)
        return if Types::AGGREGATION_STRATEGIES.include?(name)

        raise ArgumentError, "Invalid strategy: #{name}. Use: #{Types::AGGREGATION_STRATEGIES.join(", ")}"
      end

      def validate_config!
        raise ArgumentError, "Model is required. Use .model { }" unless configuration[:model_block]
        raise ArgumentError, "Proposers required. Use .proposers(n)" unless configuration[:proposer_count]

        validate_aggregator_for_strategy!
      end

      def validate_aggregator_for_strategy!
        strat = configuration[:aggregation_strategy]
        return if strat == :voting
        return if configuration[:aggregator_block]

        raise ArgumentError, "Aggregator required for #{strat} strategy. Use .aggregator { |b| ... }"
      end

      def build_proposers
        count = configuration[:proposer_count]
        Array.new(count) { |idx| build_single_proposer(idx) }
      end

      def build_single_proposer(index)
        builder = AgentBuilder.create.model(&configuration[:model_block]).tools(:final_answer)
        builder = apply_proposer_customization(builder, index) if configuration[:proposer_block]
        builder.build
      end

      def apply_proposer_customization(builder, index) = configuration[:proposer_block].call(builder, index)

      def build_aggregator
        return nil if configuration[:aggregation_strategy] == :voting

        builder = AgentBuilder.create.model(&configuration[:model_block]).tools(:final_answer)
        builder = configuration[:aggregator_block].call(builder) if configuration[:aggregator_block]
        builder.build
      end

      def build_moa_config
        Types::MoAConfig.create(
          proposer_count: configuration[:proposer_count],
          aggregation_strategy: configuration[:aggregation_strategy],
          timeout_per_proposer: configuration[:timeout_per_proposer],
          parallel: configuration[:parallel]
        )
      end

      def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))

      def field_to_config_key(name)
        { proposers: :proposer_count }[name] || name
      end
    end
  end
end
