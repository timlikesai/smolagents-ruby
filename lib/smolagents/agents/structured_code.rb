module Smolagents
  module Agents
    class StructuredCode
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Concerns::CodeExecution

      template File.join(__dir__, "../prompts/structured_code_agent.yaml")

      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **opts)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        setup_agent(tools: tools, model: model, **opts)
        finalize_code_execution
      end

      def step(task, step_number: 0)
        with_step_timing(step_number: step_number) do |action_step|
          execute_structured_code_step(task, action_step)
        end
      end

      def system_prompt
        render_prompt(:system_prompt, **code_system_prompt_variables)
      end

      private

      def execute_structured_code_step(task, action_step)
        @logger.debug("Generating structured code", task: task)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        parsed = parse_structured_response(response.content)
        unless parsed
          action_step.error = "Could not parse structured response"
          return
        end

        action_step.thoughts = parsed[:thought]
        action_step.code_action = parsed[:code]

        return unless parsed[:code]

        @logger.debug("Executing code", code: parsed[:code][0..100])
        @executor.send_variables(@state)
        result = @executor.execute(parsed[:code], language: :ruby, timeout: 30)

        if result.success?
          action_step.observations = result.logs
          action_step.action_output = result.output
          action_step.is_final_answer = result.is_final_answer
        else
          action_step.error = result.error
          action_step.observations = result.logs
        end
      end

      def parse_structured_response(content)
        json_match = content.match(/\{[^{}]*"thought"[^{}]*"code"[^{}]*\}/m) ||
                     content.match(/\{[^{}]*"code"[^{}]*"thought"[^{}]*\}/m)
        return nil unless json_match

        parsed = JSON.parse(json_match[0], symbolize_names: true)
        { thought: parsed[:thought], code: parsed[:code] }
      rescue JSON::ParserError
        nil
      end
    end
  end
end
