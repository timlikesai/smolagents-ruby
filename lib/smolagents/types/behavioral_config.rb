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
    # - +:reasoning_mode+ - Reasoning verbosity (:chain_of_thought, :chain_of_draft, :direct)
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
      :sync_events,
      :reasoning_mode,
      :tool_disclosure
    ) do
      # Creates a default config with evaluation enabled.
      #
      # @return [BehavioralConfig]
      def self.default
        new(
          evaluation_enabled: true,
          custom_instructions: nil,
          refine_config: nil,
          sync_events: false,
          reasoning_mode: :chain_of_thought,
          tool_disclosure: :progressive
        )
      end

      # Creates a behavioral config with the given options.
      #
      # @param evaluation_enabled [Boolean] Enable evaluation (default: true)
      # @param custom_instructions [String, nil] Additional instructions
      # @param refine_config [RefineConfig, nil] Refinement settings
      # @param sync_events [Boolean] Emit events synchronously (default: false)
      # @param reasoning_mode [Symbol] Reasoning verbosity (default: :chain_of_thought)
      # @param tool_disclosure [Symbol] Tool disclosure mode (default: :full)
      # @return [BehavioralConfig]
      def self.create(
        evaluation_enabled: true,
        custom_instructions: nil,
        refine_config: nil,
        sync_events: false,
        reasoning_mode: :chain_of_thought,
        tool_disclosure: :full
      )
        new(evaluation_enabled:, custom_instructions:, refine_config:, sync_events:,
            reasoning_mode:, tool_disclosure:)
      end

      # Checks if evaluation is enabled.
      #
      # @return [Boolean]
      def evaluation? = evaluation_enabled == true

      # Checks if custom instructions are set.
      #
      # @return [Boolean]
      def custom_instructions? = !custom_instructions.nil? && !custom_instructions.empty?

      # Checks if self-refinement is enabled.
      #
      # @return [Boolean]
      def refine? = refine_config&.enabled || false

      # Checks if sync events are enabled.
      #
      # @return [Boolean]
      def sync_events? = sync_events == true

      include TypeSupport::StatePredicates

      state_predicates :reasoning_mode, chain_of_draft: :chain_of_draft, direct_mode: :direct
      state_predicates :tool_disclosure, progressive_tools: :progressive
    end
  end
end
