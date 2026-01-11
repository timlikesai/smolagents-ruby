module Smolagents
  module Agents
    class Code
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Concerns::CodeExecution

      template File.join(__dir__, "../prompts/code_agent.yaml")

      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **opts)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        setup_agent(tools: tools, model: model, **opts)
        finalize_code_execution
      end

      def step(task, step_number: 0)
        with_step_timing(step_number: step_number) do |action_step|
          execute_code_step(task, action_step)
        end
      end

      def system_prompt
        render_prompt(:system_prompt, **code_system_prompt_variables)
      end
    end
  end
end
