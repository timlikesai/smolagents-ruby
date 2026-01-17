module Smolagents
  module Types
    # Configuration for agent execution behavior.
    #
    # AgentConfig groups configuration parameters that control how an agent
    # executes tasks. It separates configuration concerns from runtime
    # dependencies (model, tools, executor) that are passed directly to Agent.
    #
    # == Grouped Parameters
    #
    # - Execution limits: +:max_steps+, +:authorized_imports+
    # - Behavioral: +:custom_instructions+, +:evaluation_enabled+
    # - Planning: +:planning_interval+, +:planning_templates+
    # - Agent management: +:spawn_config+, +:memory_config+
    #
    # @example Using default config
    #   config = AgentConfig.default
    #   config.max_steps  # => 10
    #
    # @example Creating a custom config
    #   config = AgentConfig.create(
    #     max_steps: 15,
    #     planning_interval: 3,
    #     custom_instructions: "Be concise"
    #   )
    #
    # @example Modifying existing config
    #   config = AgentConfig.default.with(max_steps: 20)
    #
    # @see Agent Uses this for configuration
    # @see AgentRuntime Receives config values
    AgentConfig = Data.define(
      :max_steps,
      :planning_interval,
      :planning_templates,
      :custom_instructions,
      :evaluation_enabled,
      :authorized_imports,
      :spawn_config,
      :memory_config
    ) do
      # Creates a default configuration.
      #
      # @return [AgentConfig] Config with sensible defaults
      def self.default
        new(
          max_steps: nil,
          planning_interval: nil,
          planning_templates: nil,
          custom_instructions: nil,
          evaluation_enabled: false,
          authorized_imports: nil,
          spawn_config: nil,
          memory_config: nil
        )
      end

      # Creates a config with specified options.
      #
      # All parameters are optional and fall back to defaults.
      #
      # @param max_steps [Integer, nil] Maximum steps before stopping
      # @param planning_interval [Integer, nil] Steps between planning phases
      # @param planning_templates [Hash, nil] Planning prompt templates
      # @param custom_instructions [String, nil] Additional system prompt instructions
      # @param evaluation_enabled [Boolean] Enable metacognition evaluation
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @param spawn_config [SpawnConfig, nil] Child agent spawn config
      # @param memory_config [MemoryConfig, nil] Memory management config
      # @return [AgentConfig]
      def self.create(
        max_steps: nil,
        planning_interval: nil,
        planning_templates: nil,
        custom_instructions: nil,
        evaluation_enabled: false,
        authorized_imports: nil,
        spawn_config: nil,
        memory_config: nil
      )
        new(
          max_steps:,
          planning_interval:,
          planning_templates:,
          custom_instructions:,
          evaluation_enabled:,
          authorized_imports:,
          spawn_config:,
          memory_config:
        )
      end

      # Returns a new config with the specified changes.
      #
      # @param options [Hash] Fields to change
      # @return [AgentConfig] New config with changes applied
      #
      # @example
      #   config = Smolagents::Types::AgentConfig.default.with(max_steps: 20)
      #   config.max_steps  # => 20
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

      # Checks if spawn is enabled.
      #
      # @return [Boolean] True if spawn_config is set and enabled
      def spawn? = spawn_config&.enabled? || false

      # Checks if custom instructions are set.
      #
      # @return [Boolean] True if custom_instructions is present
      def custom_instructions? = !custom_instructions.nil? && !custom_instructions.empty?

      # Converts to a hash suitable for passing to AgentRuntime.
      #
      # Filters out nil values to allow defaults to be applied.
      #
      # @return [Hash] Config options without nil values
      def to_runtime_args
        {
          max_steps:,
          planning_interval:,
          planning_templates:,
          custom_instructions:,
          evaluation_enabled:,
          authorized_imports:,
          spawn_config:,
          memory_config:
        }.compact
      end
    end
  end
end
