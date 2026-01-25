module Smolagents
  module Concerns
    # Ruby code execution for agents.
    #
    # Orchestrates the complete code execution pipeline for code-writing agents:
    # 1. Generate code from the model ({CodeGeneration})
    # 2. Parse/extract code blocks ({CodeParsing})
    # 3. Execute in sandbox with proper context ({ExecutionContext})
    #
    # @see CodeGeneration For model to code generation
    # @see CodeParsing For code block extraction
    # @see ExecutionContext For variable scope management
    # @see CodeHints For contextual hints
    # @see BudgetTracking For step budget reminders
    # @see ObservationBuilder For observation formatting
    module CodeExecution
      def self.included(base)
        base.include(CodeGeneration)
        base.include(CodeParsing)
        base.include(ExecutionContext)
        base.include(CodeHints)
        base.include(BudgetTracking)
        base.include(ObservationBuilder)
      end

      # Execute a step by generating and running Ruby code.
      #
      # @param action_step [ActionStep] Step to update with results
      # @return [void]
      def execute_step(action_step)
        response = generate_code_response(action_step)
        result = extract_code_from_response(action_step, response)
        return unless result.success?

        execute_code_action(action_step, result.code)
      end

      private

      # Execute extracted code via executor.
      #
      # @param action_step [ActionStep] Step to update
      # @param code [String] Code to execute
      # @return [void]
      def execute_code_action(action_step, code)
        action_step.code_action = code
        @executor.send_variables(build_execution_variables(action_step))
        result = @executor.execute(code, language: :ruby, timeout: 30)
        apply_execution_result(action_step, result, code)
      end

      # Process execution result into action_step.
      #
      # @param action_step [ActionStep] Step to update
      # @param result [Executors::ExecutionResult] Execution result
      # @param code [String] The executed code for pattern detection
      # @return [void]
      def apply_execution_result(action_step, result, code = nil)
        case result
        in Executors::ExecutionResult[error: nil, output:, logs:, final_answer:]
          action_step.action_output = iterator_noise?(output) ? nil : output
          action_step.final_answer = final_answer
          action_step.observations = build_observations(action_step, output, logs, code, final_answer)
        in Executors::ExecutionResult[error:, logs:]
          action_step.error = error
          action_step.observations = with_budget_reminder(action_step, logs)
        end
      end
    end
  end
end
