module Smolagents
  module Builders
    # DSL methods for event-driven orchestration.
    #
    # Enables async execution and orchestrator integration.
    module OrchestrationConcern
      # Enables event-driven async execution mode.
      #
      # When enabled, the agent includes the EventDriven concern
      # and can use run_async for callback-based execution.
      #
      # @param enabled [Boolean] Whether to enable (default: true)
      # @return [AgentBuilder] New builder with event_driven enabled
      # @example
      #   Smolagents.agent
      #     .model { model }
      #     .event_driven
      #     .build
      def event_driven(enabled: true)
        check_frozen!
        with_config(event_driven: enabled)
      end

      # Connects the agent to an EventOrchestrator.
      #
      # The orchestrator provides centralized event routing, work
      # dispatch, and subscription management.
      #
      # @param orchestrator [Orchestrators::EventOrchestrator]
      # @return [AgentBuilder] New builder with orchestrator set
      # @example
      #   orchestrator = Smolagents::Orchestrators::EventOrchestrator.new
      #   Smolagents.agent
      #     .model { model }
      #     .event_driven
      #     .orchestrator(orchestrator)
      #     .build
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
