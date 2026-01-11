module Smolagents
  module Concerns
    module CodeExecution
      CODE_BLOCK_OPENING_TAG = "```ruby"
      CODE_BLOCK_CLOSING_TAG = "```"

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

      def execute_code_step(task, action_step)
        @logger.debug("Generating code", task: task)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        code = PatternMatching.extract_code(response.content)
        unless code
          action_step.error = "No code block found in model response"
          return
        end

        action_step.code_action = code
        @logger.debug("Executing code", code: code[0..100])
        @executor.send_variables(@state)
        result = @executor.execute(code, language: :ruby, timeout: 30)

        if result.success?
          action_step.observations = result.logs
          action_step.action_output = result.output
          action_step.is_final_answer = result.is_final_answer
          @logger.debug("Code executed successfully", output: result.output)
        else
          action_step.error = result.error
          action_step.observations = result.logs
          @logger.warn("Code execution failed", error: result.error)
        end
      end

      def code_system_prompt_variables
        {
          code_block_opening_tag: CODE_BLOCK_OPENING_TAG,
          code_block_closing_tag: CODE_BLOCK_CLOSING_TAG,
          authorized_imports: @authorized_imports.join(", ")
        }
      end
    end
  end
end
