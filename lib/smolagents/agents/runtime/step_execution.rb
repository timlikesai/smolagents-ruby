module Smolagents
  module Agents
    class AgentRuntime
      # Step execution wrapper for AgentRuntime.
      #
      # Provides the main step method that wraps timing around CodeExecution.
      #
      # @api private
      module StepExecution
        # Executes a single step in the ReAct loop.
        #
        # Performs one iteration of the ReAct pattern:
        # 1. Calls the model to generate code based on current memory
        # 2. Parses and validates the generated code
        # 3. Executes the code in the sandbox
        # 4. Records observations and updates memory
        #
        # @param _task [String] The current task (used for context, may be ignored)
        # @param step_number [Integer] Current step number (0-indexed)
        # @return [Types::ActionStep] The completed action step with observations
        def step(_task, step_number: 0)
          with_step_timing(step_number:) { |action_step| execute_step(action_step) }
        end
      end
    end
  end
end
