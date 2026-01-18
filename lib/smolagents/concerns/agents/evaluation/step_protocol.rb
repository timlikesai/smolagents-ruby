module Smolagents
  module Concerns
    module Evaluation
      # Protocol methods for working with evaluable steps.
      #
      # Steps passed to evaluation can implement:
      # - +evaluation_observation+ - String observation text
      # - +final_answer?+ - Boolean indicating task completion
      #
      # Provides fallbacks for legacy ActionStep compatibility.
      module StepProtocol
        # Extracts observation text from step using the EvaluableStep protocol.
        #
        # Steps implementing +evaluation_observation+ get that value directly.
        # Falls back to +observations+ or +action_output+ for legacy compatibility.
        #
        # @param step [#evaluation_observation, #observations, #action_output] The step
        # @return [String] Observation text (truncated to 500 chars)
        def extract_observation(step)
          obs = extract_raw_observation(step)
          obs.to_s.slice(0, 500) # Truncate for token efficiency
        end

        # Checks if step is a final answer using the EvaluableStep protocol.
        #
        # @param step [#final_answer?, #is_final_answer] The step to check
        # @return [Boolean] True if step represents task completion
        def step_is_final_answer?(step)
          if step.respond_to?(:final_answer?)
            step.final_answer?
          elsif step.respond_to?(:is_final_answer)
            step.is_final_answer
          else
            false
          end
        end

        private

        def extract_raw_observation(step)
          if step.respond_to?(:evaluation_observation)
            step.evaluation_observation
          elsif step.respond_to?(:observations)
            step.observations || step.action_output.to_s
          else
            step.to_s
          end
        end
      end
    end
  end
end
