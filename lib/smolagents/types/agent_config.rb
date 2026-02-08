module Smolagents
  module Types
    # Configuration for agent execution behavior.
    #
    # AgentConfig composes focused sub-configurations for different concerns:
    # planning, behavioral, and observability.
    #
    # == Composed Configurations
    #
    # - +:planning+ - PlanningConfig for planning intervals and templates
    # - +:behavioral+ - BehavioralConfig for evaluation, refinement, instructions
    # - +:observability+ - ObservabilityConfig for observation routing
    #
    # == Core Parameters
    #
    # - +:max_steps+ - Maximum execution steps
    # - +:authorized_imports+ - Allowed require paths for code execution
    # - +:spawn_config+ - Child agent spawn restrictions
    # - +:memory_config+ - Memory management settings
    #
    # @example Using default config
    #   config = AgentConfig.default
    #   config.max_steps          # => nil (uses global default)
    #   config.planning.enabled?  # => false
    #
    # @example Creating with composed configs
    #   config = AgentConfig.create(
    #     max_steps: 15,
    #     planning: PlanningConfig.create(interval: 3),
    #     behavioral: BehavioralConfig.create(custom_instructions: "Be concise")
    #   )
    #
    # @see Agent Uses this for configuration
    # @see AgentRuntime Receives config values
    AgentConfig = Data.define(
      :max_steps,
      :authorized_imports,
      :spawn_config,
      :memory_config,
      :planning,
      :behavioral,
      :observability,
      :token_budget,
      :parse_max_retries,
      :generation_timeout
    ) do
      # Creates a default configuration.
      #
      # @return [AgentConfig] Config with sensible defaults
      def self.default
        new(max_steps: nil, authorized_imports: nil, spawn_config: nil, memory_config: nil,
            planning: PlanningConfig.default, behavioral: BehavioralConfig.default,
            observability: ObservabilityConfig.default,
            token_budget: nil, parse_max_retries: 2, generation_timeout: nil)
      end

      # Creates a config with specified options.
      #
      # @param max_steps [Integer, nil] Maximum steps before stopping
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @param spawn_config [SpawnConfig, nil] Child agent spawn config
      # @param memory_config [MemoryConfig, nil] Memory management config
      # @param planning [PlanningConfig, nil] Planning configuration
      # @param behavioral [BehavioralConfig, nil] Behavioral configuration
      # @param observability [ObservabilityConfig, nil] Observability configuration
      # @return [AgentConfig]
      def self.create(
        max_steps: nil,
        authorized_imports: nil,
        spawn_config: nil,
        memory_config: nil,
        planning: nil,
        behavioral: nil,
        observability: nil,
        token_budget: nil,
        parse_max_retries: 2,
        generation_timeout: nil
      )
        new(max_steps:, authorized_imports:, spawn_config:, memory_config:,
            planning: planning || PlanningConfig.default,
            behavioral: behavioral || BehavioralConfig.default,
            observability: observability || ObservabilityConfig.default,
            token_budget:, parse_max_retries:, generation_timeout:)
      end

      # == Predicate Methods

      # Checks if planning is enabled.
      # @return [Boolean]
      def planning? = planning.enabled?

      # Checks if evaluation is enabled.
      # @return [Boolean]
      def evaluation? = behavioral.evaluation?

      # Checks if spawn is enabled.
      # @return [Boolean]
      def spawn? = spawn_config&.enabled? || false

      # Checks if self-refinement is enabled.
      # @return [Boolean]
      def refine? = behavioral.refine?

      # Checks if custom instructions are set.
      # @return [Boolean]
      def custom_instructions? = behavioral.custom_instructions?

      # Checks if sync events are enabled.
      # @return [Boolean]
      def sync_events? = behavioral.sync_events?

      # Converts to a hash suitable for passing to AgentRuntime.
      # @return [Hash] Config options without nil values
      def to_runtime_args = to_h.compact
    end
  end
end
