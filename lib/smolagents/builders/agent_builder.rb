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
require_relative "agent_builder/orchestration_concern"
require_relative "agent_builder/checkpoint_concern"
require_relative "agent_builder/privacy_concern"

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
      include ExecutionConcern
      include InlineToolConcern
      include MemoryConcern
      include PlanningConcern
      include RefineConcern
      include SpawnConcern
      include SpecializationConcern
      include ToolResolution
      include OrchestrationConcern
      include AgentCheckpointConcern
      include AgentPrivacyConcern

      define_handler :tool, maps_to: :tool_complete

      def self.default_configuration
        { model_block: nil, model_pool_config: nil, tool_names: [], tool_instances: [],
          planning_interval: nil, planning_templates: nil, max_steps: nil, custom_instructions: nil,
          executor: nil, authorized_imports: nil, managed_agents: {}, handlers: [], logger: nil,
          memory_config: nil, spawn_config: nil, spawn_policy: nil, evaluation_enabled: true,
          refine_config: nil, sync_events: false, observe_mode: :with_summary, summarizer_model: nil,
          event_driven: false, orchestrator: nil, step_timeout: nil, persona_name: nil,
          reasoning_mode: :chain_of_thought, call_log_enabled: false, logging_level: :quiet,
          checkpoint_config: nil, semantic_config: nil, semantic_failure_threshold: 3,
          privacy_config: nil }
      end

      # Create a new builder with default configuration.
      # @return [AgentBuilder] New builder instance
      def self.create = new(configuration: default_configuration)

      # Required methods
      register_method :model, description: "Set model (required). Use .model(:purpose) { } for multi-model",
                              required: true

      # Tool methods
      register_method :tools, description: "Add tools by name, toolkit, or instance"
      register_method :tool, description: "Define an inline tool with a block"
      register_method :authorized_imports, description: "Set authorized imports for sandboxed execution"

      # Configuration methods
      register_method :max_steps, description: "Set max steps (1-#{Config::MAX_STEPS_LIMIT})",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= Config::MAX_STEPS_LIMIT }
      register_method :planning, description: "Configure planning interval"
      register_method :memory, description: "Configure memory management (budget, strategy)"
      register_method :instructions, description: "Set custom instructions",
                                     validates: ->(v) { v.is_a?(String) && !v.empty? }
      register_method :executor, description: "Set code executor for agent"
      register_method :logger, description: "Set logger for agent output"
      register_method :observe, description: "Configure observation formatting (:with_summary or :structure_only)"
      register_method :reasoning_mode,
                      description: "Set reasoning mode (:chain_of_thought, :chain_of_draft, :direct)",
                      validates: Support::Validators.one_of(:chain_of_thought, :chain_of_draft, :direct)

      # Persona and specialization
      register_method :as, description: "Apply a persona (behavioral instructions)"
      register_method :persona, description: "Apply a persona (alias for .as)"
      register_method :with, description: "Add specialization"

      # Multi-agent
      register_method :managed_agent, description: "Add a managed sub-agent for delegation"
      register_method :can_spawn, description: "Configure spawn capability"

      # Features
      register_method :evaluation, description: "Enable structured evaluation phase"
      register_method :refine, description: "Configure self-refinement loop (arXiv:2303.17651)"
      register_method :sync_events, description: "Enable synchronous event emission (for IRB/interactive)"
      register_method :with_call_log, description: "Enable call logging for testing"
      register_method :logging, description: "Configure logging verbosity (:quiet, :info, :verbose, :debug)"
      register_method :with_checkpoints, description: "Enable state checkpointing for recovery"
      register_method :without_checkpoints, description: "Disable state checkpointing"
      register_method :with_semantic_breaker, description: "Enable semantic circuit breaker"

      # Privacy
      register_method :with_privacy, description: "Enable PII protection (default: tokenize)"
      register_method :without_privacy, description: "Disable PII protection"

      # Orchestration
      register_method :event_driven, description: "Enable event-driven async execution"
      register_method :orchestrator, description: "Connect to an EventOrchestrator"
      register_method :step_timeout, description: "Set timeout for async steps"

      # Event handlers
      register_method :on, description: "Register an event handler"

      # Execution methods
      register_method :build, description: "Create the configured agent"
      register_method :run, description: "Build and run a task in one step"
      register_method :run_fiber, description: "Build and run a task as a Fiber"

      # Enable synchronous event emission.
      # @param enabled [Boolean] Whether to enable sync events (default: true)
      # @return [AgentBuilder] New builder with sync_events enabled
      def sync_events(enabled: true)
        check_frozen!
        with_config(sync_events: enabled)
      end

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
