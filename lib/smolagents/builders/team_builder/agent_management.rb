module Smolagents
  module Builders
    # Agent management methods for TeamBuilder.
    #
    # Handles adding agents to the team, resolving AgentBuilder instances,
    # and injecting shared models into sub-agents.
    module TeamBuilderAgentManagement
      # Add an agent to the team.
      #
      # Agents can be added as either pre-built Agent instances or AgentBuilder
      # instances. If an AgentBuilder without a model is added, it will inherit
      # the team's model at build time.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for the team member (used for delegation)
      # @return [TeamBuilder] New builder with agent added
      #
      # @example Adding an agent with a model
      #   builder = Smolagents.team
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .agent(Smolagents.agent.tools(:search), as: "researcher")
      #   builder.config[:agents].key?("researcher")
      #   #=> true
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end

      private

      # Resolve an agent from either an Agent instance or AgentBuilder.
      #
      # When given an AgentBuilder without a model, injects the team's shared model.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Agent or builder to resolve
      # @return [Agent] Resolved agent instance
      def resolve_agent(agent_or_builder)
        case agent_or_builder
        when AgentBuilder then resolve_agent_builder(agent_or_builder)
        else agent_or_builder
        end
      end

      def resolve_agent_builder(builder)
        builder = inject_shared_model(builder) if needs_model_injection?(builder)
        builder.build
      end

      def needs_model_injection?(builder)
        builder.config[:model_block].nil? && configuration[:model_block]
      end

      def inject_shared_model(builder)
        builder.model(&configuration[:model_block])
      end
    end
  end
end
