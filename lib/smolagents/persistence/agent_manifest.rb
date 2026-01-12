module Smolagents
  module Persistence
    AGENT_MANIFEST_VERSION = "1.0".freeze

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

    AgentManifest = Data.define(
      :version, :agent_class, :model, :tools, :managed_agents,
      :max_steps, :planning_interval, :custom_instructions, :metadata
    ) do
      class << self
        def from_agent(agent, metadata: {})
          regular_tools = agent.tools.values.reject { |tool| tool.is_a?(ManagedAgentTool) }
          managed_agent_tools = agent.managed_agents.values

          new(
            version: AGENT_MANIFEST_VERSION,
            agent_class: agent.class.name,
            model: ModelManifest.from_model(agent.model),
            tools: regular_tools.map { |tool| ToolManifest.from_tool(tool) },
            managed_agents: managed_agent_tools.to_h { |mat| [mat.name, from_agent(mat.agent)] },
            max_steps: agent.max_steps,
            planning_interval: agent.instance_variable_get(:@planning_interval),
            custom_instructions: agent.instance_variable_get(:@custom_instructions),
            metadata: { created_at: Time.now.iso8601 }.merge(metadata)
          )
        end

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

          raise VersionMismatchError.new(data[:version], AGENT_MANIFEST_VERSION) if data[:version] && data[:version] != AGENT_MANIFEST_VERSION
          raise InvalidManifestError, errors unless errors.empty?
        end
      end

      def to_h
        {
          version:, agent_class:,
          model: model.to_h,
          tools: tools.map(&:to_h),
          managed_agents: managed_agents.transform_values(&:to_h),
          max_steps:, planning_interval:, custom_instructions:, metadata:
        }
      end

      def instantiate(model: nil, api_key: nil, **overrides)
        raise MissingModelError, self.model.class_name unless model
        raise UntrustedClassError.new(agent_class, ALLOWED_AGENT_CLASSES.to_a) unless ALLOWED_AGENT_CLASSES.include?(agent_class)

        agent_klass = Object.const_get(agent_class)
        agent_klass.new(
          model:,
          tools: tools.map(&:instantiate),
          managed_agents: instantiate_managed_agents(model, api_key, overrides),
          max_steps:, planning_interval:, custom_instructions:,
          **overrides
        )
      end

      private

      def instantiate_managed_agents(model, api_key, overrides)
        managed_agents.map do |_name, manifest|
          manifest.instantiate(model:, api_key:, **overrides)
        end
      end
    end
  end
end
