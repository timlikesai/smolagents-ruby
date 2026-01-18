module Smolagents
  module Concerns
    # Ruby code execution for agents.
    #
    # Orchestrates the complete code execution pipeline for code-writing agents:
    # 1. Generate code from the model ({CodeGeneration})
    # 2. Parse/extract code blocks ({CodeParsing})
    # 3. Execute in sandbox with proper context ({ExecutionContext})
    #
    # == Composition
    #
    # This concern auto-includes three sub-concerns:
    #
    #   CodeExecution (this concern)
    #       |
    #       +-- CodeGeneration: generate_code_response()
    #       |   - Calls @model.generate() with messages from memory
    #       |   - Captures model_output_message on action_step
    #       |
    #       +-- CodeParsing: extract_code_from_response()
    #       |   - Extracts ```ruby...``` blocks from response
    #       |   - Handles code block validation
    #       |
    #       +-- ExecutionContext: build_execution_variables()
    #           - Creates variable scope with tool references
    #           - Manages authorized_imports
    #
    # == Standalone Usage
    #
    # CodeExecution can be used independently of ReActLoop.
    # Required instance variables:
    # - @model [Model] - For generating code
    # - @executor [Executor] - For executing code
    # - @max_steps [Integer] - For budget tracking
    #
    # == Execution Flow
    #
    # The {#execute_step} method runs the full pipeline:
    #
    #   action_step = ActionStep.new(step_number: 0)
    #   execute_step(action_step)
    #   # action_step now has:
    #   # - model_output_message (from CodeGeneration)
    #   # - code_action (extracted code)
    #   # - observations (execution output)
    #   # - is_final_answer (if final_answer() was called)
    #
    # == Safety Features
    #
    # - Code runs in sandboxed executor (LocalRuby or Ractor)
    # - Step budget tracking with automatic reminders
    # - Detection of common mistakes (e.g., final_answer = x vs final_answer(x))
    #
    # @example Standalone usage (without ReActLoop)
    #   class SimpleExecutor
    #     include Concerns::CodeExecution
    #
    #     def initialize(model:, executor:, max_steps: 10)
    #       @model = model
    #       @executor = executor
    #       @max_steps = max_steps
    #     end
    #   end
    #
    # @example Usage with ReActLoop
    #   class MyCodeAgent
    #     include Concerns::ReActLoop
    #     include Concerns::CodeExecution
    #
    #     def initialize(model:, executor:)
    #       @model = model
    #       setup_code_execution(executor:)
    #       finalize_code_execution
    #     end
    #   end
    #
    # @see CodeGeneration For model to code generation
    # @see CodeParsing For code block extraction
    # @see ExecutionContext For variable scope management
    # @see Executors::LocalRuby For in-process code execution
    # @see Agents::AgentRuntime For a complete implementation
    module CodeExecution
      def self.included(base)
        base.include(CodeGeneration)
        base.include(CodeParsing)
        base.include(ExecutionContext)
      end

      # Execute a step by generating and running Ruby code.
      #
      # @param action_step [ActionStep] Step to update with results
      # @return [void]
      def execute_step(action_step)
        response = generate_code_response(action_step)
        code = extract_code_from_response(action_step, response)
        return unless code

        execute_code_action(action_step, code)
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
      # Uses pattern matching for clean result handling.
      # Automatically appends budget reminder when running low on steps.
      # Detects common mistakes like assigning to final_answer instead of calling it.
      #
      # @param action_step [ActionStep] Step to update
      # @param result [Executor::ExecutionResult] Execution result
      # @param code [String] The executed code for pattern detection
      # @return [void]
      def apply_execution_result(action_step, result, code = nil)
        case result
        in Executor::ExecutionResult[error: nil, output:, logs:, is_final_answer:]
          observations = with_code_hints(action_step, logs, code, is_final_answer)
          action_step.observations = observations
          action_step.action_output = output
          action_step.is_final_answer = is_final_answer
        in Executor::ExecutionResult[error:, logs:]
          action_step.error = error
          action_step.observations = with_budget_reminder(action_step, logs)
        end
      end

      # Add contextual hints based on code patterns.
      def with_code_hints(action_step, logs, code, is_final_answer)
        hints = []

        # Detect assignment to final_answer instead of function call
        if code && !is_final_answer && code.match?(/final_answer\s*=/)
          hints << "[HINT: final_answer is a function, not a variable. Call: final_answer(answer: your_result)]"
        end

        result = logs
        result = "#{result}\n#{hints.join("\n")}" if hints.any?
        with_budget_reminder(action_step, result)
      end

      # Appends budget reminder to observations when running low on steps.
      # Helps models know when to wrap up without explicit puts(budget).
      def with_budget_reminder(action_step, logs)
        return logs unless @max_steps

        step_num = action_step.step_number || 0
        remaining = @max_steps - step_num - 1 # -1 because this step is done

        if remaining <= 0
          "#{logs}\n[URGENT: This is your LAST step. Call final_answer NOW.]"
        elsif remaining <= 2
          "#{logs}\n[Budget: #{remaining} step#{"s" if remaining > 1} remaining]"
        else
          logs
        end
      end
    end
  end
end
