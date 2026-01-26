module Smolagents
  module Types
    # Configuration for agent setup via setup_agent().
    #
    # SetupConfig groups the many parameters required for initializing an agent's
    # ReAct loop. Instead of passing 10 individual keyword arguments, callers
    # create a SetupConfig object for cleaner method signatures.
    #
    # == Parameters
    #
    # - Required: +:tools+, +:model+
    # - Execution: +:max_steps+, +:logger+
    # - Planning: +:planning_interval+, +:planning_templates+
    # - Agent management: +:managed_agents+, +:spawn_config+
    # - Behavioral: +:custom_instructions+, +:evaluation_enabled+
    #
    # @example Creating a setup config
    #   config = SetupConfig.create(
    #     tools: { "search" => search_tool },
    #     model: my_model,
    #     max_steps: 15,
    #     planning_interval: 3
    #   )
    #   setup_agent(config)
    #
    # @example Minimal config
    #   config = SetupConfig.create(tools: tools, model: model)
    #
    # @see Concerns::ReActLoop::Core#setup_agent Uses this config
    SetupConfig = Data.define(
      :tools,
      :model,
      :max_steps,
      :planning_interval,
      :planning_templates,
      :managed_agents,
      :custom_instructions,
      :logger,
      :spawn_config,
      :evaluation_enabled
    ) do
      # Creates a setup config with the given options.
      #
      # @param tools [Hash{String => Tool}] Available tools (required)
      # @param model [Model] LLM model for generation (required)
      # @param max_steps [Integer, nil] Maximum steps (default: from global config)
      # @param planning_interval [Integer, nil] Steps between replanning
      # @param planning_templates [Hash, nil] Custom planning prompts
      # @param managed_agents [Hash{String => Agent}, nil] Sub-agents
      # @param custom_instructions [String, nil] Additional system prompt
      # @param logger [Logger, nil] Logger instance
      # @param spawn_config [SpawnConfig, nil] Child agent config
      # @param evaluation_enabled [Boolean] Enable metacognition
      # @return [SetupConfig]
      def self.create(tools:, model:, max_steps: nil, planning_interval: nil, planning_templates: nil,
                      managed_agents: nil, custom_instructions: nil, logger: nil, spawn_config: nil,
                      evaluation_enabled: false)
        new(tools:, model:, max_steps:, planning_interval:, planning_templates:, managed_agents:,
            custom_instructions:, logger:, spawn_config:, evaluation_enabled:)
      end

      # Returns a new config with the specified changes.
      #
      # @param options [Hash] Fields to change
      # @return [SetupConfig] New config with changes applied
      def with(**)
        self.class.new(**to_h, **)
      end

      # Checks if planning is enabled.
      #
      # @return [Boolean] True if planning_interval is set
      def planning? = !planning_interval.nil?

      # Checks if evaluation is enabled.
      #
      # @return [Boolean] True if evaluation_enabled is true
      def evaluation? = evaluation_enabled

      # Checks if managed agents are configured.
      #
      # @return [Boolean] True if managed_agents is present
      def managed_agents? = !managed_agents.nil? && !managed_agents.empty?
    end
  end
end
