module Smolagents
  module Concerns
    module ManagedAgents
      def self.included(base)
        base.attr_reader :managed_agents
      end

      private

      def setup_managed_agents(managed_agents)
        @managed_agents = (managed_agents || []).to_h do |agent|
          tool = agent.is_a?(ManagedAgentTool) ? agent : ManagedAgentTool.new(agent: agent)
          [tool.name, tool]
        end
      end

      def tools_with_managed_agents(tools)
        tool_hash = tools.to_h { |tool| [tool.name, tool] }

        # Always ensure final_answer is available
        tool_hash["final_answer"] ||= FinalAnswerTool.new

        tool_hash.merge(@managed_agents || {})
      end

      def managed_agent_descriptions
        return nil unless @managed_agents&.any?

        @managed_agents.values.map { |agent| "#{agent.name}: #{agent.description}" }
      end
    end
  end
end
