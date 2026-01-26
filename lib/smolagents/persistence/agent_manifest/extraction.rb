module Smolagents
  module Persistence
    # Extracts manifest data from an agent instance.
    module AgentManifestExtraction
      module_function

      # Extracts all manifest fields from an agent.
      # @param agent [Agent] The agent to extract from
      # @param metadata [Hash] Additional metadata to include
      # @return [Hash] Hash of all manifest fields
      def extract_all(agent, metadata: {})
        extract_core(agent)
          .merge(extract_tools(agent))
          .merge(metadata: build_metadata(metadata))
      end

      # Extracts core configuration fields.
      # @param agent [Agent] The agent to extract from
      # @return [Hash] Core config fields
      def extract_core(agent)
        {
          version: AgentManifestConstants::VERSION,
          agent_class: agent.class.name,
          model: ModelManifest.from_model(agent.model),
          **extract_config_fields(agent)
        }
      end

      # Extracts tools and managed agents.
      # @param agent [Agent] The agent to extract from
      # @return [Hash] Tools and managed agents
      def extract_tools(agent)
        regular_tools = agent.tools.values.reject { it.is_a?(ManagedAgentTool) }
        managed = extract_managed_agents(agent)

        {
          tools: regular_tools.map { ToolManifest.from_tool(it) },
          managed_agents: managed
        }
      end

      private_class_method def self.extract_config_fields(agent)
        AgentManifestConstants::EXTRACTABLE_FIELDS.to_h do |key, source|
          value = source.to_s.start_with?("@") ? agent.instance_variable_get(source) : agent.public_send(source)
          [key, value]
        end
      end

      private_class_method def self.extract_managed_agents(agent)
        agent.managed_agents.values.to_h do |managed|
          [managed.name, extract_all(managed.agent, metadata: {})]
        end
      end

      private_class_method def self.build_metadata(custom)
        { created_at: Time.now.iso8601 }.merge(custom)
      end
    end
  end
end
