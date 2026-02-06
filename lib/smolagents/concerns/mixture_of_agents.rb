# Mixture-of-Agents (MoA) concerns for model ensembles.
#
# MoA enables multiple proposer agents to run in parallel, with their
# outputs aggregated by different strategies for improved quality.
#
# @example Using MoA concerns
#   class MoAAgent
#     include Concerns::MixtureOfAgents::ProposerCoordination
#     include Concerns::MixtureOfAgents::AggregationStrategy
#     include Concerns::MixtureOfAgents::ResultSynthesis
#   end
#
# @see Types::MoAConfig Configuration for MoA runs
# @see Types::Proposal Individual proposer output
# @see Types::AggregationResult Combined result

require_relative "mixture_of_agents/proposer_coordination"
require_relative "mixture_of_agents/aggregation_strategy"
require_relative "mixture_of_agents/result_synthesis"

module Smolagents
  module Concerns
    # Mixture-of-Agents concerns namespace.
    # @see Types::MoAConfig For configuration options
    module MixtureOfAgents
    end
  end
end
