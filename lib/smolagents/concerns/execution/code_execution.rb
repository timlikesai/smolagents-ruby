module Smolagents
  module Concerns
    # Ruby code execution for agents.
    #
    # Provides code generation, extraction, and sandboxed execution.
    # Integrates with executors (LocalRubyExecutor, RactorExecutor, Docker).
    #
    # @see LocalRubyExecutor For in-process code execution
    # @see RactorExecutor For isolated Ractor-based execution
    # @see DockerExecutor For containerized execution
    module CodeExecution
      # Initialize code execution infrastructure.
      #
      # @param executor [Executor, nil] Code executor (defaults to LocalRubyExecutor)
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @return [void]
      def setup_code_execution(executor: nil, authorized_imports: nil)
        @authorized_imports = authorized_imports || Smolagents.configuration.authorized_imports
        @executor = executor || LocalRubyExecutor.new
      end

      # Finalize code execution setup.
      #
      # Sends the tools to the executor so code can access them.
      #
      # @return [void]
      def finalize_code_execution
        @executor.send_tools(@tools)
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

      # Generate code response from model.
      #
      # @param action_step [ActionStep] Step to update with model output
      # @return [ChatMessage] Model response
      def generate_code_response(action_step)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end

      # Extract Ruby code from model response.
      #
      # Uses PatternMatching to find code blocks (```ruby...```).
      #
      # @param action_step [ActionStep] Step to update on error
      # @param response [ChatMessage] Model response
      # @return [String, nil] Extracted code or nil
      def extract_code_from_response(action_step, response)
        code = PatternMatching.extract_code(response.content)
        action_step.error = "No code block found in response" unless code
        code
      end

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

      # Builds variables hash for code execution.
      #
      # Includes state variables, step context, and spawn function if configured.
      #
      # @param action_step [ActionStep, nil] Current step for context
      # @return [Hash] Variables to inject into execution sandbox
      def build_execution_variables(action_step = nil)
        vars = @state.dup
        vars["spawn"] = create_spawn_function if @spawn_config

        # Add step context so agent knows where they are in the budget
        if action_step && @max_steps
          step_num = action_step.step_number || 0
          vars["_step"] = step_num
          vars["_max_steps"] = @max_steps
          vars["_steps_remaining"] = [@max_steps - step_num, 0].max
        end

        vars
      end

      # Creates a spawn function for child agent creation.
      #
      # @return [Proc] Lambda that creates and runs child agents
      def create_spawn_function
        Runtime::Spawn.create_spawn_function(
          spawn_config: @spawn_config,
          parent_memory: @memory,
          parent_model: @model
        )
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
