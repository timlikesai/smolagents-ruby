module Smolagents
  module Concerns
    module ManagedAgents
      def self.included(base)
        base.attr_reader :managed_agents
      end

      private

      def setup_managed_agents(managed_agents)
        @managed_agents = (managed_agents || []).to_h do |a|
          t = a.is_a?(ManagedAgentTool) ? a : ManagedAgentTool.new(agent: a)
          [t.name, t]
        end
      end

      def tools_with_managed_agents(tools)
        tools.to_h { |t| [t.name, t] }.merge(@managed_agents || {})
      end
    end
  end
end
