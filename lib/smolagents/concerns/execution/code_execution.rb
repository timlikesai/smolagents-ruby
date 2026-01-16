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
        @executor.send_variables(build_execution_variables)
        result = @executor.execute(code, language: :ruby, timeout: 30)
        apply_execution_result(action_step, result)
      end

      # Builds variables hash for code execution.
      #
      # Includes state variables and spawn function if spawn_config is set.
      #
      # @return [Hash] Variables to inject into execution sandbox
      def build_execution_variables
        vars = @state.dup
        vars["spawn"] = create_spawn_function if @spawn_config
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
      #
      # @param action_step [ActionStep] Step to update
      # @param result [Executor::ExecutionResult] Execution result
      # @return [void]
      def apply_execution_result(action_step, result)
        case result
        in Executor::ExecutionResult[error: nil, output:, logs:, is_final_answer:]
          action_step.observations = logs
          action_step.action_output = output
          action_step.is_final_answer = is_final_answer
        in Executor::ExecutionResult[error:, logs:]
          action_step.error = error
          action_step.observations = logs
        end
      end
    end
  end
end
