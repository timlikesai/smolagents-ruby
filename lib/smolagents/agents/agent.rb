module Smolagents
  module Agents
    class Agent
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents

      def initialize(tools:, model:, **opts)
        setup_agent(tools: tools, model: model, **opts)
      end

      def step(task, step_number: 0)
        with_step_timing(step_number: step_number) { |s| execute_step(s) }
      end

      def system_prompt = raise(NotImplementedError)
      def execute_step(_) = raise(NotImplementedError)
    end
  end
end
