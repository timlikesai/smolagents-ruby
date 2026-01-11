module Smolagents
  module Agents
    class Base
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents

      def initialize(tools:, model:, **opts)
        setup_agent(tools: tools, model: model, **opts)
      end

      def step(task, step_number: 0)
        with_step_timing(step_number: step_number) do |action_step|
          execute_step(action_step)
        end
      end

      def system_prompt
        render_prompt(:system_prompt, **system_prompt_variables)
      end

      private

      def execute_step(_action_step)
        raise NotImplementedError, "#{self.class} must implement execute_step"
      end

      def system_prompt_variables
        {}
      end
    end
  end
end
