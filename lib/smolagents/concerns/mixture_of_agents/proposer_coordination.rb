# Parallel execution of proposer agents in Mixture-of-Agents pattern.
#
# Coordinates multiple proposer agents running in parallel, collecting their
# proposals for later aggregation. Uses AgentFuture for async execution.
#
# @see Types::Proposal, Types::MoAConfig
module Smolagents
  module Concerns
    module MixtureOfAgents
      # Parallel proposer execution for MoA pattern.
      #
      # @example Running proposers in parallel
      #   proposals = run_proposers_parallel(task, proposers, moa_config)
      #   proposals.each { |p| puts "#{p.proposer_name}: #{p.confidence}" }
      module ProposerCoordination
        def self.included(base)
          base.include(Events::Emitter) unless base < Events::Emitter
        end

        # Runs all proposers in parallel, returning their proposals.
        #
        # @param task [String] Task to assign to each proposer
        # @param proposers [Array<Agent>] Proposer agents to run
        # @param config [Types::MoAConfig] Configuration for timeouts and parallelism
        # @return [Array<Types::Proposal>] Proposals from each proposer
        def run_proposers_parallel(task, proposers, config)
          futures = launch_proposers(task, proposers, config)
          collect_proposals(task, futures, config)
        end

        private

        def launch_proposers(task, proposers, config)
          proposers.map.with_index do |proposer, idx|
            emit_proposer_launched(idx, task, proposers.size)
            create_proposer_future(proposer, task, config)
          end
        end

        def create_proposer_future(proposer, task, config)
          future = Executors::AgentFuture.new(
            agent: proposer,
            task:,
            timeout: config.timeout_per_proposer
          )
          future.execute!
        end

        def collect_proposals(task, futures, config)
          futures.map.with_index do |future, idx|
            collect_single_proposal(task, future, idx, config)
          end.compact
        end

        def collect_single_proposal(task, future, idx, _config)
          result = future.value
          proposal = Types::Proposal.from_run_result("proposer_#{idx}", task, result)
          emit_proposal_received(proposal)
          proposal
        rescue Executors::TimeoutError, Executors::CancellationError => e
          emit_error(e, context: { proposer_index: idx }, recoverable: true)
          nil
        end

        def emit_proposer_launched(idx, task, total)
          emit :proposer_launched,
               proposer_name: "proposer_#{idx}",
               proposer_index: idx,
               task:,
               total_proposers: total
        end

        def emit_proposal_received(proposal)
          emit :proposal_received,
               proposer_name: proposal.proposer_name,
               confidence: proposal.confidence,
               duration_ms: proposal.duration_ms,
               result_preview: proposal.result.to_s[0..100]
        end
      end
    end
  end
end
