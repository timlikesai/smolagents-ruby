module Smolagents
  module Concerns
    module CodeExecution
      def self.included(base)
        base.attr_reader :executor, :authorized_imports
      end

      def setup_code_execution(executor: nil, authorized_imports: nil)
        @authorized_imports = authorized_imports || Smolagents.configuration.authorized_imports
        @executor = executor || LocalRubyExecutor.new
      end

      def finalize_code_execution
        @executor.send_tools(@tools)
      end

      def template_path = nil

      def system_prompt
        Prompts::Presets.code_agent(
          tools: @tools.values.map(&:to_code_prompt),
          team: managed_agent_descriptions,
          custom: @custom_instructions
        )
      end

      def execute_step(action_step)
        response = generate_code_response(action_step)
        code = extract_code_from_response(action_step, response)
        return unless code

        execute_code_action(action_step, code)
      end

      private

      def generate_code_response(action_step)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        response
      end

      def extract_code_from_response(action_step, response)
        code = PatternMatching.extract_code(response.content)
        action_step.error = "No code block found in response" unless code
        code
      end

      def execute_code_action(action_step, code)
        action_step.code_action = code
        @executor.send_variables(@state)
        result = @executor.execute(code, language: :ruby, timeout: 30)
        apply_execution_result(action_step, result)
      end

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
