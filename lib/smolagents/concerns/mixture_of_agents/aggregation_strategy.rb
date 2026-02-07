# Aggregation strategies for Mixture-of-Agents pattern.
#
# Provides different methods to combine multiple proposals into a final result:
# - Voting: select highest confidence proposal
# - Synthesis: use aggregator agent to synthesize all proposals
# - Rank fusion: aggregator ranks and weights proposals
#
# @see Types::AggregationResult, Types::Proposal
module Smolagents
  module Concerns
    module MixtureOfAgents
      # Aggregation strategies for combining MoA proposals.
      #
      # @example Voting (fastest)
      #   result = aggregate_by_voting(proposals)
      #
      # @example Synthesis (highest quality)
      #   result = aggregate_by_synthesis(proposals, aggregator, task)
      module AggregationStrategy
        def self.included(base)
          base.include(Events::Emitter) unless base < Events::Emitter
        end

        # Selects the highest confidence proposal.
        #
        # @param proposals [Array<Types::Proposal>] Proposals to aggregate
        # @return [Types::AggregationResult] Result with winning proposal
        def aggregate_by_voting(proposals)
          start_time = monotonic_now
          result = Types::AggregationResult.from_voting(proposals)
          emit_aggregation_completed(:voting, result, elapsed_ms(start_time))
          result.with(duration_ms: elapsed_ms(start_time))
        end

        # Uses aggregator agent to synthesize all proposals.
        #
        # @param proposals [Array<Types::Proposal>] Proposals to synthesize
        # @param aggregator [Agent] Agent that performs synthesis
        # @param task [String] Original task for context
        # @return [Types::AggregationResult] Synthesized result
        def aggregate_by_synthesis(proposals, aggregator, task)
          start_time = monotonic_now
          synthesis_result = aggregator.run(build_synthesis_prompt(proposals, task))
          result = build_synthesis_result(proposals, synthesis_result, elapsed_ms(start_time))
          emit_aggregation_completed(:synthesis, result, elapsed_ms(start_time))
          result
        end

        # Uses aggregator to rank proposals and compute weighted result.
        #
        # @param proposals [Array<Types::Proposal>] Proposals to rank
        # @param aggregator [Agent] Agent that performs ranking
        # @param task [String] Original task for context
        # @return [Types::AggregationResult] Rank-fused result
        def aggregate_by_rank_fusion(proposals, aggregator, task)
          start_time = monotonic_now
          ranking_result = aggregator.run(build_ranking_prompt(proposals, task))
          result = build_rank_fusion_result(proposals, ranking_result, elapsed_ms(start_time))
          emit_aggregation_completed(:rank_fusion, result, elapsed_ms(start_time))
          result
        end

        private

        def format_proposals_for_aggregator(proposals)
          proposals.map.with_index do |proposal, idx|
            confidence = proposal.confidence ? " (confidence: #{(proposal.confidence * 100).round}%)" : ""
            "## Proposal #{idx + 1}: #{proposal.proposer_name}#{confidence}\n#{proposal.result}"
          end.join("\n\n")
        end

        def build_synthesis_prompt(proposals, task)
          <<~PROMPT
            You are an aggregator agent. Synthesize the following proposals into a single, comprehensive answer.

            **Original Task:** #{task}

            **Proposals to synthesize:**
            #{format_proposals_for_aggregator(proposals)}

            **Instructions:**
            - Identify the key insights from each proposal
            - Combine the strongest elements into a unified answer
            - Resolve any contradictions between proposals
            - Provide a comprehensive final answer
          PROMPT
        end

        def build_ranking_prompt(proposals, task)
          <<~PROMPT
            You are an aggregator agent. Rank and evaluate the following proposals, then provide a weighted synthesis.

            **Original Task:** #{task}

            **Proposals to evaluate:**
            #{format_proposals_for_aggregator(proposals)}

            **Instructions:**
            - Rank each proposal by quality, accuracy, and completeness
            - Assign weights based on your rankings
            - Produce a final answer that weighs contributions by their quality
            - Explain your ranking rationale briefly
          PROMPT
        end

        def build_synthesis_result(proposals, synthesis_result, duration_ms)
          Types::AggregationResult.from_synthesis(
            proposals,
            synthesis_result.output,
            extract_reasoning(synthesis_result),
            duration_ms:
          )
        end

        def build_rank_fusion_result(proposals, ranking_result, duration_ms)
          Types::AggregationResult.new(
            final_answer: ranking_result.output,
            selected_proposal: nil,
            strategy: :rank_fusion,
            all_proposals: proposals,
            synthesis_reasoning: extract_reasoning(ranking_result),
            duration_ms:
          )
        end

        def extract_reasoning(run_result) = run_result.action_steps.filter_map(&:observations).join("\n\n")

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def elapsed_ms(start_time)
          ((monotonic_now - start_time) * 1000).round
        end

        def emit_aggregation_completed(strategy, result, duration_ms)
          emit :moa_lifecycle, phase: :aggregation_completed,
                               strategy:,
                               proposal_count: result.proposal_count,
                               selected_proposer: result.selected_proposal,
                               final_confidence: result.confidence_estimate,
                               duration_ms:
        end
      end
    end
  end
end
