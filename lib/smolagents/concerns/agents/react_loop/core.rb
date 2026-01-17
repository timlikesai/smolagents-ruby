module Smolagents
  module Concerns
    module ReActLoop
      # Agent setup, run entry points, and memory access.
      #
      # Provides the foundational methods for agent initialization and execution:
      #
      # - {#setup_agent} - Initialize agent state, tools, memory, and optional features
      # - {#run} - Main entry point for sync or streaming execution
      # - {#run_fiber} - Fiber-based execution for bidirectional control
      #
      # == Lifecycle
      #
      # 1. Agent includes {ReActLoop} (which includes Core)
      # 2. Agent calls {#setup_agent} with configuration
      # 3. User calls {#run} or {#run_fiber} to execute tasks
      # 4. Core delegates to {Execution} for the main loop
      #
      # == Memory Management
      #
      # Core creates and manages {AgentMemory} which tracks:
      # - System prompt
      # - Task prompts
      # - Action steps (code, observations, errors)
      # - Planning steps (if planning enabled)
      #
      # @example Setup in a custom agent with SetupConfig
      #   class MyAgent
      #     include Concerns::ReActLoop
      #
      #     def initialize(model:, tools:)
      #       config = Types::SetupConfig.create(model:, tools:, max_steps: 10)
      #       setup_agent(config)
      #     end
      #   end
      #
      # @see Execution For the main loop implementation
      # @see Planning For optional planning integration
      # @see Evaluation For optional metacognition
      # @see Types::SetupConfig For configuration options
      module Core
        # Initialize agent state, tools, memory, and optional features.
        #
        # This is the main setup method that must be called before {#run}.
        # It configures all agent components and initializes optional features.
        #
        # @param config [Types::SetupConfig] Configuration object with all setup parameters
        # @return [void]
        #
        # @example
        #   config = Types::SetupConfig.create(
        #     tools: { "search" => search_tool },
        #     model: my_model,
        #     max_steps: 15
        #   )
        #   setup_agent(config)
        def setup_agent(config)
          setup_core_and_planning(config)
          setup_agents_and_memory(config)
        end

        def setup_core_and_planning(config)
          initialize_core_state(model: config.model, max_steps: config.max_steps, logger: config.logger,
                                custom_instructions: config.custom_instructions, spawn_config: config.spawn_config)
          initialize_planning(planning_interval: config.planning_interval,
                              planning_templates: config.planning_templates)
          initialize_evaluation(evaluation_enabled: config.evaluation_enabled)
        end

        def setup_agents_and_memory(config)
          setup_managed_agents(config.managed_agents)
          @tools = tools_with_managed_agents(config.tools)
          @memory = AgentMemory.new(system_prompt)
        end

        # Execute a task using the ReAct loop.
        #
        # This is the main entry point for agent execution. It can run
        # synchronously (returning a final result) or streaming (returning
        # an Enumerator of steps).
        #
        # @param task [String] The task/question for the agent
        # @param stream [Boolean] If true, return Enumerator<ActionStep>
        # @param reset [Boolean] If true, reset memory before running
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions for this run
        # @return [Types::RunResult] Final result (sync mode)
        # @return [Enumerator<Types::ActionStep>] Step enumerator (stream mode)
        #
        # @example Synchronous execution
        #   result = agent.run("What is 2+2?")
        #   puts result.output  # => "4"
        #
        # @example Streaming execution
        #   agent.run("Complex task", stream: true).each do |step|
        #     puts "Step #{step.step_number}: #{step.observations}"
        #   end
        #
        # @see #run_fiber For bidirectional control flow
        def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
          Types::ObservabilityContext.with_context do |obs_ctx|
            instrument_run(task, obs_ctx) { execute_run(task, stream, reset, images, additional_prompting) }
          end
        end

        def instrument_run(task, obs_ctx, &)
          Instrumentation.instrument("smolagents.agent.run", task:, agent_class: self.class.name,
                                                             trace_id: obs_ctx.trace_id, &)
        end

        def execute_run(task, stream, reset, images, additional_prompting)
          prepare_run(reset, images)
          stream ? run_stream(task:, images:, additional_prompting:) : run_sync(task, images:, additional_prompting:)
        end

        # Fiber-based execution with bidirectional control.
        #
        # Returns a Fiber that yields execution steps and control requests.
        # This enables interactive agent sessions where external code can
        # respond to agent requests for input, confirmation, or escalation.
        #
        # == Fiber Protocol
        #
        # The Fiber yields one of three types:
        #
        # - {Types::ActionStep} - A completed step (resume with nil to continue)
        # - {Types::ControlRequests::Request} - Agent needs input (resume with Response)
        # - {Types::RunResult} - Task complete (Fiber ends)
        #
        # @param task [String] The task/question for the agent
        # @param reset [Boolean] If true, reset memory before running
        # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
        # @param additional_prompting [String, nil] Extra instructions for this run
        # @return [Fiber] Fiber that yields ActionStep, ControlRequest, or RunResult
        #
        # @example Interactive execution with user input
        #   fiber = agent.run_fiber("Research topic X")
        #   loop do
        #     result = fiber.resume
        #     case result
        #     in Types::ControlRequests::UserInput => req
        #       answer = prompt_user(req.prompt)
        #       fiber.resume(Types::ControlRequests::Response.respond(request_id: req.id, value: answer))
        #     in Types::ControlRequests::Confirmation => req
        #       approved = confirm_action(req.description)
        #       fiber.resume(Types::ControlRequests::Response.new(request_id: req.id, approved:))
        #     in Types::RunResult => final
        #       break final
        #     end
        #   end
        #
        # @see Control For control request methods (request_input, request_confirmation)
        def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
          Fiber.new do
            Instrumentation.instrument("smolagents.agent.run_fiber", task:, agent_class: self.class.name) do
              reset_state if reset
              @task_images = images
              fiber_loop(task:, additional_prompting:, images:)
            end
          end
        end

        def fiber_context? = Thread.current[:smolagents_fiber_context] == true
        def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode:)

        private

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

        def run_sync(task, images:, additional_prompting:)
          consume_fiber(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def run_stream(task:, images: nil, additional_prompting: nil)
          drain_fiber_to_enumerator(run_fiber(task, reset: false, images:, additional_prompting:))
        end

        def drain_fiber_to_enumerator(fiber)
          Enumerator.new do |y|
            loop do
              case fiber.resume
              in Types::ActionStep => s then y << s
              in Types::ControlRequests::Request => req then fiber.resume(auto_approve(req))
              in RunResult then break
              end
            end
          end
        end

        def auto_approve(req) = Types::ControlRequests::Response.approve(request_id: req.id)

        # Default consume_fiber for sync execution (overridden by Control concern).
        # Auto-approves all control requests.
        def consume_fiber(fiber)
          loop do
            case fiber.resume
            in Types::ActionStep then next
            in Types::ControlRequests::Request => req then fiber.resume(auto_approve(req))
            in Types::RunResult => final then return final
            end
          end
        end
      end
    end
  end
end
