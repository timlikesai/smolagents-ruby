module Smolagents
  module Agents
    class StructuredCode < Base
      include Concerns::StructuredCodeExecution

      template File.join(__dir__, "../prompts/structured_code_agent.yaml")

      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **opts)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        super
        finalize_code_execution
      end

      private

      def execute_step(action_step)
        execute_structured_code_step(action_step)
      end

      def system_prompt_variables
        code_system_prompt_variables
      end
    end
  end
end
