# frozen_string_literal: true

module Smolagents
  module Agents
    class Agent
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents

      def initialize(tools:, model:, **)
        setup_agent(tools: tools, model: model, **)
      end

      def step(_task, step_number: 0)
        with_step_timing(step_number: step_number) { |s| execute_step(s) }
      end

      def system_prompt = raise(NotImplementedError)
      def execute_step(_) = raise(NotImplementedError)
    end

    # Factory methods
    def self.code(model:, tools: [], **) = Code.new(model:, tools:, **)
    def self.tool_calling(model:, tools: [], **) = ToolCalling.new(model:, tools:, **)
  end
end
