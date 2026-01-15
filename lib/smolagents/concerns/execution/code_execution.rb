module Smolagents
  module Concerns
    # CodeAgent execution with Ruby code generation and sandboxed execution
    #
    # Manages code generation flow for agents that write Ruby code to call tools.
    # Integrates with executors (LocalRubyExecutor, RactorExecutor, Docker) and
    # handles code extraction, execution, and result processing.
    #
    # @example Implementing a CodeAgent
    #   class MyCodeAgent
    #     include Concerns::CodeExecution
    #     include Concerns::ReActLoop
    #
    #     def initialize(tools:, model:)
    #       setup_code_execution
    #       # ...
    #     end
    #   end
    #
    # @see LocalRubyExecutor For in-process code execution
    # @see RactorExecutor For isolated Ractor-based execution
    # @see DockerExecutor For containerized execution
    module CodeExecution
      # Hook called when module is included
      # @api private
      def self.included(base)
        base.attr_reader :executor, :authorized_imports
      end

      # Initialize code execution infrastructure
      #
      # Sets up the executor (defaults to LocalRubyExecutor) and
      # authorized imports list from configuration.
      #
      # @param executor [Executor, nil] Code executor (defaults to LocalRubyExecutor)
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @return [void]
      def setup_code_execution(executor: nil, authorized_imports: nil)
        @authorized_imports = authorized_imports || Smolagents.configuration.authorized_imports
        @executor = executor || LocalRubyExecutor.new
      end

      # Finalize code execution setup
      #
      # Sends the tools to the executor so code can access them.
      #
      # @return [void]
      def finalize_code_execution
        @executor.send_tools(@tools)
      end

      # Template path for custom prompts (override in subclasses)
      # @return [nil] Not used (yields to subclass override)
      def template_path = nil

      # System prompt for CodeAgent
      #
      # Combines base code agent prompt with tool descriptions and
      # optional capabilities addendum.
      #
      # @return [String] Complete system prompt
      # @see Prompts::CodeAgent For base prompt
      def system_prompt
        base_prompt = Prompts::CodeAgent.generate(
          tools: @tools.values.map(&:to_code_prompt),
          team: managed_agent_descriptions,
          authorized_imports: @authorized_imports,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool usage patterns
      #
      # Provides examples of how to use tools in code format.
      #
      # @return [String] Capabilities prompt addendum (empty string if no tools)
      # @see Prompts.generate_capabilities For generation logic
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools: @tools,
          managed_agents: @managed_agents,
          agent_type: :code
        )
      end

      # Execute a step by generating and running code
      #
      # Generates Ruby code from model, extracts it, and executes via executor.
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

      # Generate code response from model
      #
      # Calls model.generate with memory and captures response/tokens.
      #
      # @param action_step [ActionStep] Step to update with model output
      # @return [ChatMessage] Model response
      # @api private
      def generate_code_response(action_step)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end

      # Extract Ruby code from model response
      #
      # Uses PatternMatching to find code blocks (```ruby...```)
      # Sets error on action_step if no code found.
      #
      # @param action_step [ActionStep] Step to update on error
      # @param response [ChatMessage] Model response
      # @return [String, nil] Extracted code or nil
      # @api private
      def extract_code_from_response(action_step, response)
        code = PatternMatching.extract_code(response.content)
        action_step.error = "No code block found in response" unless code
        code
      end

      # Execute extracted code via executor
      #
      # Sends state variables to executor, runs code, and applies results.
      #
      # @param action_step [ActionStep] Step to update
      # @param code [String] Code to execute
      # @return [void]
      # @api private
      def execute_code_action(action_step, code)
        action_step.code_action = code
        @executor.send_variables(@state)
        result = @executor.execute(code, language: :ruby, timeout: 30)
        apply_execution_result(action_step, result)
      end

      # Process execution result into action_step
      #
      # Handles both success (output, logs) and error cases.
      #
      # @param action_step [ActionStep] Step to update
      # @param result [Executor::ExecutionResult] Execution result
      # @return [void]
      # @api private
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
