module Smolagents
  module Builders
    # Managed agent configuration for multi-agent orchestration.
    #
    # Allows adding sub-agents that can be delegated tasks.
    module ManagedAgentsConcern
      # Add a managed sub-agent for multi-agent orchestration.
      #
      # Managed agents can be delegated tasks by the parent agent.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Sub-agent or builder
      # @param as [String, Symbol] Name for the sub-agent (used for delegation)
      # @return [AgentBuilder] New builder with managed agent added
      #
      # @example Adding a managed agent
      #   sub_agent = Smolagents.agent
      #     .tools(:search)
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .build
      #   builder = Smolagents.agent.managed_agent(sub_agent, as: :researcher)
      #   builder.config[:managed_agents].key?("researcher")
      #   #=> true
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with_config(managed_agents: configuration[:managed_agents].merge(as.to_s => resolved))
      end
    end
  end
end
