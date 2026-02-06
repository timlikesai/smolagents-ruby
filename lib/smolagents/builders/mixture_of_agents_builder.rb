require_relative "mixture_of_agents_builder/build_concern"

module Smolagents
  module Builders
    # Fluent builder for Mixture-of-Agents (MoA) configuration.
    #
    # MoA runs multiple proposer agents in parallel, aggregating their outputs
    # for improved quality through model ensemble consensus.
    #
    # @example Basic MoA with 3 proposers
    #   moa = Smolagents.mixture_of_agents
    #     .model { OpenAIModel.new("gpt-4o-mini") }
    #     .proposers(3)
    #     .strategy(:voting)
    #     .build
    #
    #   result = moa.run("What's the capital of France?")
    #
    # @example Custom proposers with different personas
    #   moa = Smolagents.mixture_of_agents
    #     .model { model }
    #     .proposers(3) do |builder, index|
    #       builder.persona("Expert #{index + 1}").tools(:search)
    #     end
    #     .aggregator { |b| b.persona("Synthesizer") }
    #     .strategy(:synthesis)
    #     .timeout(per_proposer: 30)
    #     .build
    #
    # @see Types::MoAConfig, Types::Proposal, Types::AggregationResult
    MixtureOfAgentsBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers
      include MoABuildConcern

      def self.default_configuration
        { model_block: nil, proposer_count: nil, proposer_block: nil, aggregator_block: nil,
          aggregation_strategy: :voting, timeout_per_proposer: 30, parallel: true,
          handlers: [] }
      end

      # @return [MixtureOfAgentsBuilder]
      def self.create = new(configuration: default_configuration)

      register_method :model, description: "Set model (required)", required: true
      register_method :proposers, description: "Configure proposer count (2-20)", required: true,
                                  validates: ->(v) { v.is_a?(Integer) && v.between?(2, 20) }
      register_method :aggregator, description: "Configure aggregator agent (for synthesis/rank_fusion)"
      register_method :strategy, description: "Set aggregation strategy (:voting, :synthesis, :rank_fusion)"
      register_method :timeout, description: "Set timeout per proposer"
      register_method :parallel, description: "Enable/disable parallel execution"
      register_method :on, description: "Register an event handler"
      register_method :build, description: "Create the configured MoA coordinator"
      register_method :run, description: "Build and run a task in one step"

      # Set the model for proposers and aggregator. Evaluated lazily at build time.
      def model(&block)
        check_frozen!
        with_config(model_block: block)
      end

      # Configure proposers (2-20). Optional block customizes each proposer.
      def proposers(count, &block)
        check_frozen!
        validate!(:proposers, count)
        with_config(proposer_count: count, proposer_block: block)
      end

      # Configure aggregator agent (required for synthesis/rank_fusion strategies).
      def aggregator(&block)
        check_frozen!
        with_config(aggregator_block: block)
      end

      # Set aggregation strategy: :voting, :synthesis, or :rank_fusion.
      def strategy(name)
        check_frozen!
        validate_strategy!(name)
        with_config(aggregation_strategy: name)
      end

      # Set timeout per proposer in seconds.
      def timeout(per_proposer:)
        check_frozen!
        with_config(timeout_per_proposer: per_proposer)
      end

      # Enable or disable parallel proposer execution (default: true).
      def parallel(enabled: true)
        check_frozen!
        with_config(parallel: enabled)
      end

      # Build the MoA coordinator.
      def build
        validate_config!
        MoACoordinator.new(
          proposers: build_proposers,
          aggregator: build_aggregator,
          config: build_moa_config,
          handlers: configuration[:handlers]
        )
      end

      # Build and run a task.
      def run(task) = build.run(task)

      def config = configuration.dup

      def inspect
        strat = configuration[:aggregation_strategy]
        count = configuration[:proposer_count] || "?"
        "#<MixtureOfAgentsBuilder proposers=#{count} strategy=#{strat}>"
      end
    end
  end
end
