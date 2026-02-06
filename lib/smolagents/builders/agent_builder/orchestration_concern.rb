module Smolagents
  module Builders
    # DSL methods for multi-agent orchestration and event-driven execution.
    module OrchestrationConcern
      # Add a managed sub-agent for multi-agent orchestration.
      #
      # @param agent_or_builder [Agent, AgentBuilder] Sub-agent or builder
      # @param as [String, Symbol] Name for the sub-agent (used for delegation)
      # @return [AgentBuilder] New builder with managed agent added
      def managed_agent(agent_or_builder, as:)
        resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
        with_config(managed_agents: configuration[:managed_agents].merge(as.to_s => resolved))
      end

      # Enables event-driven async execution mode.
      #
      # @param enabled [Boolean] Whether to enable (default: true)
      # @return [AgentBuilder] New builder with event_driven enabled
      def event_driven(enabled: true)
        check_frozen!
        with_config(event_driven: enabled)
      end

      # Connects the agent to an EventOrchestrator.
      #
      # @param orchestrator [Orchestrators::EventOrchestrator]
      # @return [AgentBuilder] New builder with orchestrator set
      def orchestrator(orchestrator)
        check_frozen!
        with_config(orchestrator:, event_driven: true)
      end

      # Sets the step timeout for async execution.
      #
      # @param seconds [Numeric] Timeout in seconds
      # @return [AgentBuilder] New builder with step_timeout set
      def step_timeout(seconds)
        check_frozen!
        with_config(step_timeout: seconds)
      end
    end
  end
end
