module Smolagents
  module Concerns
    module StructuredCodeExecution
      include CodeExecution

      def execute_structured_code_step(action_step)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        parsed = parse_thought_and_code(response.content)
        unless parsed
          action_step.error = "Could not parse structured response (expected JSON with thought and code)"
          return
        end

        action_step.thoughts = parsed[:thought]
        action_step.code_action = parsed[:code]

        return unless parsed[:code]

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

      private

      def parse_thought_and_code(content)
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
