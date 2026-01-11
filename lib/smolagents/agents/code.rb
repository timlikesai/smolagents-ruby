module Smolagents
  module Agents
    class Code < Base
      include Concerns::CodeExecution

      template File.join(__dir__, "../prompts/code_agent.yaml")

      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **opts)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        super
        finalize_code_execution
      end

      private

      def execute_step(action_step)
        execute_code_step(action_step)
      end

      def system_prompt_variables
        code_system_prompt_variables
      end
    end
  end
end
