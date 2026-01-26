module Smolagents
  module Types
    # Configuration for agent behavioral characteristics.
    #
    # BehavioralConfig groups settings that affect how an agent behaves
    # during task execution: metacognition, self-refinement, custom
    # instructions, and event synchronization.
    #
    # == Options
    #
    # - +:evaluation_enabled+ - Enable metacognition evaluation phase
    # - +:custom_instructions+ - Additional system prompt instructions
    # - +:refine_config+ - Self-refinement configuration
    # - +:sync_events+ - Whether to emit events synchronously
    #
    # @example Default behavioral config
    #   config = BehavioralConfig.default
    #   config.evaluation?  # => true
    #   config.refine?      # => false
    #
    # @example Custom behavioral config
    #   config = BehavioralConfig.create(
    #     evaluation_enabled: true,
    #     custom_instructions: "Be concise",
    #     sync_events: true
    #   )
    #
    # @see Concerns::Agents::Evaluation Metacognition evaluation
    # @see Concerns::Agents::SelfRefine Self-refinement loop
    BehavioralConfig = Data.define(
      :evaluation_enabled,
      :custom_instructions,
      :refine_config,
      :sync_events
    ) do
      # Creates a default config with evaluation enabled.
      #
      # @return [BehavioralConfig]
      def self.default
        new(
          evaluation_enabled: true,
          custom_instructions: nil,
          refine_config: nil,
          sync_events: false
        )
      end

      # Creates a behavioral config with the given options.
      #
      # @param evaluation_enabled [Boolean] Enable evaluation (default: true)
      # @param custom_instructions [String, nil] Additional instructions
      # @param refine_config [RefineConfig, nil] Refinement settings
      # @param sync_events [Boolean] Emit events synchronously (default: false)
      # @return [BehavioralConfig]
      def self.create(
        evaluation_enabled: true,
        custom_instructions: nil,
        refine_config: nil,
        sync_events: false
      )
        new(evaluation_enabled:, custom_instructions:, refine_config:, sync_events:)
      end

      # Checks if evaluation is enabled.
      #
      # @return [Boolean]
      def evaluation? = evaluation_enabled == true

      # Checks if custom instructions are set.
      #
      # @return [Boolean]
      def custom_instructions?
        !custom_instructions.nil? && !custom_instructions.empty?
      end

      # Checks if self-refinement is enabled.
      #
      # @return [Boolean]
      def refine? = refine_config&.enabled || false

      # Checks if sync events are enabled.
      #
      # @return [Boolean]
      def sync_events? = sync_events == true
    end
  end
end
