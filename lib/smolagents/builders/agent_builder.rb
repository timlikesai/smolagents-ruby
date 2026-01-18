require_relative "base"
require_relative "event_handlers"
require_relative "execution_concern"
require_relative "inline_tool_concern"
require_relative "memory_concern"
require_relative "planning_concern"
require_relative "refine_concern"
require_relative "spawn_concern"
require_relative "specialization_concern"
require_relative "tool_resolution"
require_relative "agent_builder/model_concern"
require_relative "agent_builder/tools_concern"
require_relative "agent_builder/setters_concern"
require_relative "agent_builder/build_concern"
require_relative "agent_builder/managed_agents_concern"

module Smolagents
  module Builders
    # Chainable builder for configuring agents with a fluent DSL.
    #
    # Build agents with composable atoms:
    # - Model: +.model { }+ - the LLM (required)
    # - Tools: +.tools(:search)+ - what the agent uses
    # - Persona: +.as(:researcher)+ - behavioral instructions
    # - Specialization: +.with(:researcher)+ - tools + persona combo
    #
    # @example Minimal agent
    #   agent = Smolagents.agent.model { OpenAIModel.new(model_id: "gpt-4") }.build
    #
    # @see Toolkits, Personas, Specializations
    AgentBuilder = Data.define(:configuration) do
      include Base
      include EventHandlers
      include ModelConcern
      include AgentToolsConcern
      include AgentSettersConcern
      include AgentBuildConcern
      include ManagedAgentsConcern
      include ExecutionConcern
      include InlineToolConcern
      include MemoryConcern
      include PlanningConcern
      include RefineConcern
      include SpawnConcern
      include SpecializationConcern
      include ToolResolution

      define_handler :tool, maps_to: :tool_complete

      def self.default_configuration
        { model_block: nil, tool_names: [], tool_instances: [], planning_interval: nil, planning_templates: nil,
          max_steps: nil, custom_instructions: nil, executor: nil, authorized_imports: nil, managed_agents: {},
          handlers: [], logger: nil, memory_config: nil, spawn_config: nil, spawn_policy: nil,
          evaluation_enabled: true, refine_config: nil }
      end

      # Create a new builder with default configuration.
      # @return [AgentBuilder] New builder instance
      def self.create = new(configuration: default_configuration)

      register_method :model, description: "Set model (required)", required: true
      register_method :max_steps, description: "Set max steps (1-#{Config::MAX_STEPS_LIMIT})",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }
      register_method :planning, description: "Configure planning interval"
      register_method :memory, description: "Configure memory management (budget, strategy)"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :persona, description: "Apply a persona (alias for .as)"
      register_method :with, description: "Add specialization"
      register_method :can_spawn, description: "Configure spawn capability"
      register_method :evaluation, description: "Enable structured evaluation phase"
      register_method :refine, description: "Configure self-refinement loop (arXiv:2303.17651)"

      private

      # Create a new builder with merged configuration.
      # @param kwargs [Hash] Configuration updates
      # @return [AgentBuilder] New builder with merged configuration
      def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))

      # Map method names to configuration keys for introspection.
      # @param name [Symbol] Field name
      # @return [Symbol] Configuration key
      def field_to_config_key(name)
        { model: :model_block }[name] || name
      end
    end
  end
end
