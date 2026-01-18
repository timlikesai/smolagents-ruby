module Smolagents
  module Concerns
    module ReActLoop
      # Agent initialization and configuration.
      #
      # Handles setup of core state, planning, evaluation, tools, and memory.
      # This is extracted from Core to keep initialization logic focused.
      #
      # @see Core For the main entry point
      module Setup
        # Initialize agent state, tools, memory, and optional features.
        #
        # @param config [Types::SetupConfig] Configuration object
        # @return [void]
        def setup_agent(config)
          setup_core_and_planning(config)
          setup_agents_and_memory(config)
        end

        private

        def setup_core_and_planning(config)
          initialize_core_state(**core_state_params(config))
          initialize_planning(planning_interval: config.planning_interval,
                              planning_templates: config.planning_templates)
          initialize_evaluation(evaluation_enabled: config.evaluation_enabled)
        end

        def core_state_params(config)
          { model: config.model, max_steps: config.max_steps, logger: config.logger,
            custom_instructions: config.custom_instructions, spawn_config: config.spawn_config }
        end

        def setup_agents_and_memory(config)
          setup_managed_agents(config.managed_agents)
          @tools = tools_with_managed_agents(config.tools)
          @memory = AgentMemory.new(system_prompt)
        end

        def initialize_core_state(model:, max_steps:, logger:, custom_instructions:, spawn_config: nil)
          config = Smolagents.configuration
          @model = model
          @max_steps = max_steps || config.max_steps
          @logger = logger || Logging::NullLogger.instance
          @state = {}
          @spawn_config = spawn_config
          @custom_instructions = PromptSanitizer.sanitize(
            custom_instructions || config.custom_instructions,
            logger: @logger
          )
        end

        # No-op stub for evaluation initialization (opt-in via Evaluation concern)
        def initialize_evaluation(evaluation_enabled: false)
          @evaluation_enabled = evaluation_enabled
        end

        def reset_state
          @memory.reset
          @state = {}
        end

        def prepare_run(reset, images)
          return unless reset || images

          reset_state if reset
          @task_images = images
        end

        def prepare_task(task, additional_prompting: nil, images: nil)
          @memory.add_task(task, additional_prompting:, task_images: images)
        end
      end
    end
  end
end
