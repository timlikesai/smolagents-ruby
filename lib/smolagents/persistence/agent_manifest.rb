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
          regular_tools = agent.tools.values.reject { |t| t.is_a?(ManagedAgentTool) }
          managed_agent_tools = agent.managed_agents.values

          new(
            version: AGENT_MANIFEST_VERSION,
            agent_class: agent.class.name,
            model: ModelManifest.from_model(agent.model),
            tools: regular_tools.map { |t| ToolManifest.from_tool(t) },
            managed_agents: managed_agent_tools.to_h { |mat| [mat.name, from_agent(mat.agent)] },
            max_steps: agent.max_steps,
            planning_interval: agent.instance_variable_get(:@planning_interval),
            custom_instructions: agent.instance_variable_get(:@custom_instructions),
            metadata: { created_at: Time.now.iso8601 }.merge(metadata)
          )
        end

        def from_h(hash)
          h = Serialization.deep_symbolize_keys(hash)
          validate!(h)

          new(
            version: h[:version],
            agent_class: h[:agent_class],
            model: ModelManifest.from_h(h[:model]),
            tools: (h[:tools] || []).map { |t| ToolManifest.from_h(t) },
            managed_agents: (h[:managed_agents] || {}).transform_values { |v| from_h(v) },
            max_steps: h[:max_steps],
            planning_interval: h[:planning_interval],
            custom_instructions: h[:custom_instructions],
            metadata: h[:metadata] || {}
          )
        end

        private

        def validate!(h)
          errors = []
          errors << "missing version" unless h[:version]
          errors << "missing agent_class" unless h[:agent_class]
          errors << "missing model" unless h[:model]

          raise VersionMismatchError.new(h[:version], AGENT_MANIFEST_VERSION) if h[:version] && h[:version] != AGENT_MANIFEST_VERSION
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
