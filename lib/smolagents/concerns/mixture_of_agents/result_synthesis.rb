# Result synthesis for Mixture-of-Agents pattern.
#
# Converts aggregation results and proposals into a final RunResult
# suitable for returning from an agent run.
#
# @see Types::RunResult, Types::AggregationResult
module Smolagents
  module Concerns
    module MixtureOfAgents
      # Synthesizes MoA results into RunResult format.
      #
      # @example Building final result
      #   run_result = build_moa_result(aggregation, proposals, 1500)
      module ResultSynthesis
        # Builds a RunResult from MoA aggregation output.
        #
        # @param aggregation_result [Types::AggregationResult, Types::Proposal, Object]
        # @param proposals [Array<Types::Proposal>] All proposals considered
        # @param duration_ms [Integer] Total MoA execution time
        # @return [Types::RunResult] Final run result
        def build_moa_result(aggregation_result, proposals, duration_ms)
          output = extract_moa_output(aggregation_result)

          Types::RunResult.new(
            output:,
            state: determine_state(aggregation_result, proposals),
            steps: build_moa_steps(proposals),
            token_usage: aggregate_token_usage(proposals),
            timing: build_moa_timing(duration_ms)
          )
        end

        private

        def extract_moa_output(result)
          case result
          in Types::AggregationResult => ar then ar.final_answer
          in Types::Proposal => p then p.result
          else result
          end
        end

        def determine_state(result, proposals)
          return :error if proposals.empty?
          return :success if result.is_a?(Types::AggregationResult)

          proposals.any?(&:high_confidence?) ? :success : :partial
        end

        def build_moa_steps(proposals)
          proposals.map.with_index { |proposal, idx| proposal_to_action_step(proposal, idx) }
        end

        def proposal_to_action_step(proposal, idx)
          Types::ActionStep.new(
            step_number: idx + 1,
            observations: "Proposer #{proposal.proposer_name}: #{proposal.result.to_s[0..500]}"
          )
        end

        def aggregate_token_usage(_proposals) = nil

        def build_moa_timing(duration_ms)
          end_time = Time.now
          start_time = end_time - (duration_ms / 1000.0)
          Types::Timing.new(start_time:, end_time:)
        end
      end
    end
  end
end
