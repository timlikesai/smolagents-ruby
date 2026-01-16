module Smolagents
  module Concerns
    module ReActLoop
      # Agent initialization and state setup.
      module Setup
        # Initialize agent state and memory with tools, model, and configuration.
        #
        # @param tools [Array<Tool>] Tools available to the agent
        # @param model [Model] Language model for generation
        # @param max_steps [Integer, nil] Maximum steps before stopping
        # @param planning_interval [Integer, nil] Steps between planning updates
        # @param planning_templates [Hash, nil] Custom planning prompt templates
        # @param managed_agents [Array<Agent>, nil] Sub-agents for orchestration
        # @param custom_instructions [String, nil] Custom system instructions
        # @param logger [Logger, nil] Logger instance
        # @param spawn_config [Types::SpawnConfig, nil] Configuration for spawning child agents
        # @return [void]
        def setup_agent(tools:, model:, max_steps: nil, planning_interval: nil, planning_templates: nil,
                        managed_agents: nil, custom_instructions: nil, logger: nil, spawn_config: nil, **_opts)
          initialize_core_state(model:, max_steps:, logger:, custom_instructions:, spawn_config:)
          initialize_planning(planning_interval:, planning_templates:)
          setup_managed_agents(managed_agents)
          @tools = tools_with_managed_agents(tools)
          @memory = AgentMemory.new(system_prompt)
        end

        private

        def initialize_core_state(model:, max_steps:, logger:, custom_instructions:, spawn_config: nil)
          config = Smolagents.configuration
          @model = model
          @max_steps = max_steps || config.max_steps
          @logger = logger || AgentLogger.new(output: $stderr, level: AgentLogger::WARN)
          @state = {}
          @spawn_config = spawn_config
          @custom_instructions = PromptSanitizer.sanitize(
            custom_instructions || config.custom_instructions,
            logger: @logger
          )
        end

        def reset_state
          @memory.reset
          @state = {}
        end

        def prepare_task(task, additional_prompting: nil, images: nil)
          @memory.add_task(task, additional_prompting:, task_images: images)
        end
      end
    end
  end
end
