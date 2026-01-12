module Smolagents
  module Agents
    class Agent
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Persistence::Serializable

      def initialize(tools:, model:, **)
        setup_agent(tools: tools, model: model, **)
      end

      def step(_task, step_number: 0)
        with_step_timing(step_number: step_number) { |action_step| execute_step(action_step) }
      end

      def system_prompt = raise(NotImplementedError)
      def execute_step(_) = raise(NotImplementedError)
    end

    def self.code(model:, tools: [], **) = Code.new(model:, tools:, **)
    def self.tool_calling(model:, tools: [], **) = ToolCalling.new(model:, tools:, **)
  end
end
