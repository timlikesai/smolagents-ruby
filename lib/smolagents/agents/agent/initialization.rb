module Smolagents
  module Agents
    class Agent
      # Initialization logic for Agent.
      #
      # Handles configuration, tool setup, memory creation, and runtime building.
      # Separated to keep the main Agent class focused on the public interface.
      #
      # @api private
      module Initialization
        private

        # Initialize core components from parameters.
        #
        # @param model [Models::Model] The LLM model
        # @param executor [Executors::Executor, nil] Code executor
        # @param logger [Logging::Logger, nil] Logger instance
        # @param agent_config [Types::AgentConfig] Configuration object
        # @return [void]
        def initialize_core(model:, executor:, logger:, agent_config:)
          global_config = Smolagents.configuration
          @model = model
          @executor = executor || LocalRubyExecutor.new
          @authorized_imports = agent_config.authorized_imports || global_config.authorized_imports
          @max_steps = agent_config.max_steps || global_config.max_steps
          @logger = logger || Logging::NullLogger.instance
          instructions = agent_config.custom_instructions || global_config.custom_instructions
          @custom_instructions = PromptSanitizer.sanitize(instructions, logger: @logger)
          @spawn_config = agent_config.spawn_config
        end

        # Initialize tools and managed agents.
        #
        # @param tools [Array<Tools::Tool>] Tools to register
        # @param managed_agents [Hash{String => Agent}, nil] Sub-agents
        # @return [void]
        def initialize_tools(tools, managed_agents)
          setup_managed_agents(managed_agents)
          @tools = tools_with_managed_agents(tools)
          @executor.send_tools(@tools)
        end

        # Initialize memory and runtime.
        #
        # @param agent_config [Types::AgentConfig] Configuration
        # @return [void]
        def initialize_memory_and_runtime(agent_config)
          mem_config = agent_config.memory_config || Types::MemoryConfig.default
          @memory = AgentMemory.new(system_prompt, config: mem_config)
          @runtime = build_runtime(agent_config)
          @runtime.event_queue = @event_queue if @event_queue
        end

        # Build the runtime with configuration.
        #
        # @param agent_config [Types::AgentConfig] Configuration
        # @return [AgentRuntime] The configured runtime
        def build_runtime(agent_config)
          AgentRuntime.new(
            model: @model, tools: @tools, executor: @executor, memory: @memory,
            max_steps: @max_steps, logger: @logger, custom_instructions: @custom_instructions,
            planning_interval: agent_config.planning_interval,
            planning_templates: agent_config.planning_templates,
            spawn_config: agent_config.spawn_config,
            evaluation_enabled: agent_config.evaluation_enabled,
            authorized_imports: @authorized_imports
          )
        end
      end
    end
  end
end
