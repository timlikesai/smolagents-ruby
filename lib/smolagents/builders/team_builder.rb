require_relative "support/flexible_input"
require_relative "team_builder/resolution_concern"

module Smolagents
  module Builders
    # Chainable builder for multi-agent teams. Creates a coordinator agent that
    # delegates to specialized sub-agents. Sub-agents without models inherit the team's model.
    #
    # @example
    #   team = Smolagents.team
    #     .model { OpenAIModel.new(model_id: "gpt-4") }
    #     .agent(Smolagents.agent.tools(:search), as: "researcher")
    #     .coordinate("Delegate research tasks")
    #     .build
    TeamBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers
      include Support::FlexibleInput
      include TeamResolutionConcern

      define_handler :agent, maps_to: :agent_complete

      def self.default_configuration
        { agents: {}, model_block: nil, coordinator_instructions: nil, coordinator_type: :code,
          max_steps: nil, planning_interval: nil, handlers: [] }
      end

      # @return [TeamBuilder]
      def self.create = new(configuration: default_configuration)

      register_method :agent, description: "Add team member", required: true
      register_method :model, description: "Set shared model for coordinator and sub-agents"
      register_method :max_steps, description: "Set max coordinator steps (1-#{Config::MAX_STEPS_LIMIT})",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }
      register_method :coordinate, description: "Set coordination instructions",
                                   validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :coordinator, description: "Set coordinator agent type (:code or :tool)"
      register_method :planning, description: "Configure planning interval"
      register_method :build, description: "Create the configured team coordinator"

      # Set the shared model for coordinator and sub-agents. Evaluated lazily at build time.
      # @yield Block returning a Model instance
      # @return [TeamBuilder] New builder with model configured
      def model(&block) = with_config(model_block: block)

      # Add an agent to the team. AgentBuilders without models inherit the team's model.
      # @param agent_or_builder [Agent, AgentBuilder] Agent to add
      # @param as [String, Symbol] Name for the team member (used for delegation)
      # @return [TeamBuilder] New builder with agent added
      def agent(agent_or_builder, as:)
        check_frozen!
        raise ArgumentError, "Agent name required" if as.to_s.empty?

        resolved = resolve_agent(agent_or_builder)
        with_config(agents: configuration[:agents].merge(as.to_s => resolved))
      end

      # Set coordination instructions guiding how to delegate tasks and combine results.
      # @param instructions [String] How to coordinate sub-agents
      # @return [TeamBuilder] New builder with instructions set
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end

      # Set coordinator type: :code (writes code) or :tool (uses tool calling).
      def coordinator(type) = with_config(coordinator_type: type.to_sym)

      # Set maximum steps for the coordinator agent.
      # @param count [Integer] Maximum steps (1-Config::MAX_STEPS_LIMIT)
      # @return [TeamBuilder] New builder with max steps set
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Configure planning for the coordinator.
      # Accepts: planning(), planning(5), planning(interval: 5), planning(false)
      #
      # @param value [Integer, Boolean, Symbol] Interval or toggle
      # @param interval [Integer, nil] Keyword alternative for interval
      # @return [TeamBuilder] New builder with planning configured
      def planning(value = Support::FlexibleInput::UNSET, interval: nil)
        check_frozen!
        resolved = resolve_value_or_toggle(
          value, interval, value_type: Integer, default: Config::DEFAULT_PLANNING_INTERVAL, name: "planning"
        )
        with_config(planning_interval: resolved)
      end

      # Build the team coordinator with all configured sub-agents.
      # @return [Agent] Coordinator agent with managed sub-agents
      # @raise [ArgumentError] If no agents have been added
      def build
        validate_config!
        coordinator = build_coordinator(resolve_model, resolve_agent_class)
        register_handlers(coordinator)
        coordinator
      end

      def config = configuration.dup

      def inspect
        agent_names = configuration[:agents].keys.join(", ")
        "#<TeamBuilder agents=[#{agent_names}] coordinator=#{configuration[:coordinator_type]}>"
      end
    end
  end
end
