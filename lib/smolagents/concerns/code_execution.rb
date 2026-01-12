# frozen_string_literal: true

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
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        code = PatternMatching.extract_code(response.content)
        unless code
          action_step.error = "No code block found in response"
          return
        end

        action_step.code_action = code
        @executor.send_variables(@state)
        result = @executor.execute(code, language: :ruby, timeout: 30)

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

      def managed_agent_descriptions
        return nil unless @managed_agents&.any?

        @managed_agents.values.map { |a| "#{a.name}: #{a.description}" }
      end
    end
  end
end
