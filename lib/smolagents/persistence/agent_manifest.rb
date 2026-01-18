require_relative "agent_manifest/constants"
require_relative "agent_manifest/extraction"
require_relative "agent_manifest/validation"
require_relative "agent_manifest/instantiation"

module Smolagents
  module Persistence
    # Immutable manifest describing an agent's configuration for persistence.
    # Captures all information needed to reconstruct an agent (except API keys).
    #
    # @example manifest = AgentManifest.from_agent(agent); manifest.instantiate(model: my_model)
    # @see DirectoryFormat For file persistence
    AgentManifest = Data.define(
      :version, :agent_class, :model, :tools, :managed_agents,
      :max_steps, :planning_interval, :custom_instructions, :metadata
    ) do
      class << self
        # Creates a manifest from an existing agent instance.
        #
        # @param agent [Agent] The agent to capture
        # @param metadata [Hash] Additional metadata to include
        # @return [AgentManifest] Manifest capturing agent's configuration
        def from_agent(agent, metadata: {})
          data = AgentManifestExtraction.extract_all(agent, metadata:)
          new(**data)
        end

        # Creates a manifest from a hash (e.g., parsed JSON).
        #
        # @param hash [Hash] Hash representation of the manifest
        # @return [AgentManifest] Reconstructed manifest
        # @raise [VersionMismatchError] If manifest version is unsupported
        # @raise [InvalidManifestError] If required fields are missing
        def from_h(hash)
          data = Serialization.deep_symbolize_keys(hash)
          AgentManifestValidation.validate!(data)
          build_from_data(data)
        end

        private

        # rubocop:disable Metrics/MethodLength -- manifest construction
        def build_from_data(data)
          new(
            version: data[:version],
            agent_class: data[:agent_class],
            model: ModelManifest.from_h(data[:model]),
            tools: (data[:tools] || []).map { ToolManifest.from_h(it) },
            managed_agents: (data[:managed_agents] || {}).transform_values { from_h(it) },
            max_steps: data[:max_steps],
            planning_interval: data[:planning_interval],
            custom_instructions: data[:custom_instructions],
            metadata: data[:metadata] || {}
          )
        end
        # rubocop:enable Metrics/MethodLength
      end

      # Converts the manifest to a hash for JSON serialization.
      # @return [Hash] Hash representation of the manifest
      def to_h
        {
          version:, agent_class:,
          model: model.to_h,
          tools: tools.map(&:to_h),
          managed_agents: managed_agents.transform_values(&:to_h),
          max_steps:, planning_interval:, custom_instructions:, metadata:
        }
      end

      # Creates an agent instance from this manifest.
      #
      # For local models (LM Studio, Ollama, llama.cpp), the model is restored
      # automatically. For cloud providers, checks environment variables for
      # API keys. If neither works, you must provide a model explicitly.
      #
      # @param model [Model, nil] Model instance to use (auto-detected if nil)
      # @param api_key [String, nil] API key for model/tool initialization
      # @param overrides [Hash] Settings to override (e.g., max_steps)
      # @return [Agent] New agent instance
      # @raise [MissingModelError] If model cannot be auto-created and none provided
      # @raise [UntrustedClassError] If agent_class is not in allowed list
      def instantiate(model: nil, api_key: nil, **overrides)
        AgentManifestInstantiation.instantiate(self, model:, api_key:, **overrides)
      end
    end
  end
end
