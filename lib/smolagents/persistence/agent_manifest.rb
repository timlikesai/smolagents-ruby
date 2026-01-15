module Smolagents
  module Persistence
    # @return [String] Current manifest format version
    AGENT_MANIFEST_VERSION = "1.0".freeze

    # @return [Set<String>] Agent classes allowed to be loaded from manifests.
    #   Prevents arbitrary code execution via malicious manifests.
    ALLOWED_AGENT_CLASSES = Set.new(%w[
                                      Smolagents::Agents::Code
                                      Smolagents::Agents::ToolCalling
                                      Smolagents::Agents::Assistant
                                      Smolagents::Agents::Calculator
                                      Smolagents::Agents::DataAnalyst
                                      Smolagents::Agents::FactChecker
                                      Smolagents::Agents::Researcher
                                      Smolagents::Agents::Transcriber
                                      Smolagents::Agents::WebScraper
                                    ]).freeze

    # Immutable manifest describing an agent's configuration.
    #
    # AgentManifest captures all the information needed to reconstruct
    # an agent, except for API keys (which are never serialized).
    # Manifests can be serialized to JSON for persistence.
    #
    # @example Creating from an agent
    #   manifest = AgentManifest.from_agent(agent, metadata: { version: "1.0" })
    #   json = manifest.to_h.to_json
    #
    # @example Loading from JSON
    #   manifest = AgentManifest.from_h(JSON.parse(json))
    #   agent = manifest.instantiate(model: my_model)
    #
    # @example Structure
    #   {
    #     version: "1.0",
    #     agent_class: "Smolagents::Agents::Code",
    #     model: {
    #       class_name: "OpenAIModel",
    #       model_id: "gemma-3n-e4b-it-q8_0",
    #       provider: "lm_studio",  # Enables automatic model recovery
    #       config: {}
    #     },
    #     tools: [{ name: "search", class_name: "WebSearchTool", config: {} }],
    #     managed_agents: {},
    #     max_steps: 10,
    #     planning_interval: nil,
    #     custom_instructions: nil,
    #     metadata: { created_at: "2024-01-15T..." }
    #   }
    #
    # @see Serializable For the save/load interface
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
          new(
            **extract_core_config(agent),
            **extract_tools_config(agent),
            metadata: { created_at: Time.now.iso8601 }.merge(metadata)
          )
        end

        def extract_core_config(agent)
          { version: AGENT_MANIFEST_VERSION, agent_class: agent.class.name,
            model: ModelManifest.from_model(agent.model), max_steps: agent.max_steps,
            planning_interval: agent.instance_variable_get(:@planning_interval),
            custom_instructions: agent.instance_variable_get(:@custom_instructions) }
        end

        def extract_tools_config(agent)
          regular_tools = agent.tools.values.reject { it.is_a?(ManagedAgentTool) }
          managed = agent.managed_agents.values.to_h { [it.name, from_agent(it.agent)] }
          { tools: regular_tools.map { ToolManifest.from_tool(it) }, managed_agents: managed }
        end

        # Creates a manifest from a hash (e.g., parsed JSON).
        #
        # @param hash [Hash] Hash representation of the manifest
        # @return [AgentManifest] Reconstructed manifest
        # @raise [VersionMismatchError] If manifest version is unsupported
        # @raise [InvalidManifestError] If required fields are missing
        def from_h(hash)
          data = Serialization.deep_symbolize_keys(hash)
          validate!(data)

          new(
            version: data[:version],
            agent_class: data[:agent_class],
            model: ModelManifest.from_h(data[:model]),
            tools: (data[:tools] || []).map { |tool_hash| ToolManifest.from_h(tool_hash) },
            managed_agents: (data[:managed_agents] || {}).transform_values { |manifest_hash| from_h(manifest_hash) },
            max_steps: data[:max_steps],
            planning_interval: data[:planning_interval],
            custom_instructions: data[:custom_instructions],
            metadata: data[:metadata] || {}
          )
        end

        private

        def validate!(data)
          errors = []
          errors << "missing version" unless data[:version]
          errors << "missing agent_class" unless data[:agent_class]
          errors << "missing model" unless data[:model]

          if data[:version] && data[:version] != AGENT_MANIFEST_VERSION
            raise VersionMismatchError.new(data[:version],
                                           AGENT_MANIFEST_VERSION)
          end
          raise InvalidManifestError, errors unless errors.empty?
        end
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
        resolved_model = resolve_model(model, api_key, overrides)
        validate_agent_class!
        build_agent(resolved_model, api_key, overrides)
      end

      private

      def resolve_model(model, api_key, overrides)
        resolved = model || self.model.auto_instantiate(api_key:, **overrides)
        raise MissingModelError, self.model.class_name unless resolved

        resolved
      end

      def validate_agent_class!
        return if ALLOWED_AGENT_CLASSES.include?(agent_class)

        raise UntrustedClassError.new(agent_class, ALLOWED_AGENT_CLASSES.to_a)
      end

      def build_agent(resolved_model, api_key, overrides)
        Object.const_get(agent_class).new(
          model: resolved_model,
          tools: tools.map(&:instantiate),
          managed_agents: instantiate_managed_agents(resolved_model, api_key, overrides),
          max_steps:, planning_interval:, custom_instructions:,
          **overrides
        )
      end

      def instantiate_managed_agents(model, api_key, overrides)
        managed_agents.map { |_name, manifest| manifest.instantiate(model:, api_key:, **overrides) }
      end
    end
  end
end
