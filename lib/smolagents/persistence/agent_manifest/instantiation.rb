module Smolagents
  module Persistence
    # Creates agent instances from manifest data.
    module AgentManifestInstantiation
      module_function

      # Creates an agent instance from manifest data.
      # @param manifest [AgentManifest] The manifest to instantiate
      # @param model [Model, nil] Model instance to use (auto-detected if nil)
      # @param api_key [String, nil] API key for model/tool initialization
      # @param overrides [Hash] Settings to override
      # @return [Agent] New agent instance
      def instantiate(manifest, model: nil, api_key: nil, **overrides)
        resolved_model = resolve_model(manifest, model, api_key, overrides)
        AgentManifestValidation.validate_agent_class!(manifest.agent_class)
        build_agent(manifest, resolved_model, api_key, overrides)
      end

      private_class_method def self.resolve_model(manifest, model, api_key, overrides)
        resolved = model || manifest.model.auto_instantiate(api_key:, **overrides)
        raise MissingModelError, manifest.model.class_name unless resolved

        resolved
      end

      private_class_method def self.build_agent(manifest, resolved_model, api_key, overrides)
        Object.const_get(manifest.agent_class).new(
          model: resolved_model,
          tools: manifest.tools.map(&:instantiate),
          managed_agents: instantiate_managed_agents(manifest, resolved_model, api_key, overrides),
          config: build_config(manifest, overrides)
        )
      end

      private_class_method def self.build_config(manifest, overrides)
        Types::AgentConfig.create(
          max_steps: overrides[:max_steps] || manifest.max_steps,
          planning_interval: overrides[:planning_interval] || manifest.planning_interval,
          custom_instructions: overrides[:custom_instructions] || manifest.custom_instructions
        )
      end

      private_class_method def self.instantiate_managed_agents(manifest, model, api_key, overrides)
        manifest.managed_agents.map do |_name, sub_manifest|
          instantiate(sub_manifest, model:, api_key:, **overrides)
        end
      end
    end
  end
end
