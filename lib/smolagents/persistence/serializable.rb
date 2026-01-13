module Smolagents
  module Persistence
    # Concern that adds save/load capabilities to agent classes.
    #
    # When included in an agent class, Serializable provides instance methods
    # for saving to disk and class methods for loading from saved configurations.
    # API keys are never serialized for security.
    #
    # @example Saving an agent
    #   agent = Smolagents::Agents::Code.new(model: my_model, tools: [search, calc])
    #   agent.save("./saved_agents/my_agent", metadata: { version: "1.0" })
    #
    # @example Loading an agent
    #   loaded = Smolagents::Agents::Agent.from_folder(
    #     "./saved_agents/my_agent",
    #     model: OpenAIModel.new(model_id: "gpt-4", api_key: ENV["OPENAI_API_KEY"])
    #   )
    #
    # @example Converting to manifest without saving
    #   manifest = agent.to_manifest(metadata: { author: "Tim" })
    #   puts manifest.to_h.to_json
    #
    # @see DirectoryFormat For the file format used by save/load
    # @see AgentManifest For the manifest structure
    module Serializable
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Saves the agent to a directory.
      #
      # Creates a directory structure containing:
      # - agent.json: Main manifest with agent configuration
      # - tools/: Tool manifests
      # - managed_agents/: Recursively saved sub-agents
      #
      # @param path [String, Pathname] Directory path to save to
      # @param metadata [Hash] Additional metadata to include
      # @return [Pathname] The path where agent was saved
      def save(path, metadata: {})
        DirectoryFormat.save(self, path, metadata:)
      end

      # Converts the agent to a manifest without saving.
      #
      # @param metadata [Hash] Additional metadata to include
      # @return [AgentManifest] The agent's manifest
      def to_manifest(metadata: {})
        AgentManifest.from_agent(self, metadata:)
      end

      # Class methods added when Serializable is included.
      module ClassMethods
        # Loads an agent from a saved directory.
        #
        # The model must be provided since API keys are never saved.
        #
        # @param path [String, Pathname] Directory path to load from
        # @param model [Model] Model instance (required)
        # @param api_key [String, nil] API key for tool initialization
        # @param overrides [Hash] Settings to override from manifest
        # @return [Agent] Reconstructed agent instance
        # @raise [MissingModelError] If model is not provided
        # @raise [Errno::ENOENT] If directory or manifest doesn't exist
        def from_folder(path, model: nil, api_key: nil, **overrides)
          DirectoryFormat.load(path, model:, api_key:, **overrides)
        end

        # Creates an agent from a manifest object.
        #
        # @param manifest [AgentManifest] The manifest to instantiate
        # @param model [Model] Model instance (required)
        # @param api_key [String, nil] API key for tool initialization
        # @param overrides [Hash] Settings to override from manifest
        # @return [Agent] Reconstructed agent instance
        def from_manifest(manifest, model: nil, api_key: nil, **overrides)
          manifest.instantiate(model:, api_key:, **overrides)
        end
      end
    end
  end
end
