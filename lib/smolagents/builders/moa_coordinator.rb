module Smolagents
  module Builders
    # MoA coordinator that runs proposers and aggregates results.
    #
    # This is a lightweight coordinator that uses the MoA concerns for actual
    # execution and aggregation logic.
    #
    # @see Concerns::MixtureOfAgents::ProposerCoordination
    # @see Concerns::MixtureOfAgents::AggregationStrategy
    # @see Concerns::MixtureOfAgents::ResultSynthesis
    class MoACoordinator
      include Concerns::MixtureOfAgents::ProposerCoordination
      include Concerns::MixtureOfAgents::AggregationStrategy
      include Concerns::MixtureOfAgents::ResultSynthesis

      attr_reader :proposers, :aggregator, :config

      def initialize(proposers:, aggregator:, config:, handlers: [])
        @proposers = proposers
        @aggregator = aggregator
        @config = config
        register_handlers(handlers)
      end

      # Run the MoA pipeline on a task.
      # @param task [String] Task to execute
      # @return [Types::RunResult] Aggregated result
      def run(task)
        start_time = monotonic_now
        proposals = run_proposers_parallel(task, proposers, config)
        aggregation_result = aggregate_proposals(task, proposals)
        build_moa_result(aggregation_result, proposals, elapsed_ms(start_time))
      end

      private

      def register_handlers(handlers)
        handlers.each { |event_type, block| on(event_type, &block) }
      end

      def aggregate_proposals(task, proposals)
        case config.aggregation_strategy
        when :voting then aggregate_by_voting(proposals)
        when :synthesis then aggregate_by_synthesis(proposals, aggregator, task)
        when :rank_fusion then aggregate_by_rank_fusion(proposals, aggregator, task)
        end
      end

      def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      def elapsed_ms(start_time) = ((monotonic_now - start_time) * 1000).round
    end
  end
end
