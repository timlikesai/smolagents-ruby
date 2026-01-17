module Smolagents
  module Agents
    # An agent that writes Ruby code to accomplish tasks.
    #
    # Agents generate Ruby code that calls tools, performs computations,
    # uses loops/conditionals, and stores intermediate results. Code executes
    # in a sandboxed environment with configurable safety limits.
    #
    # Agent handles configuration and prompt generation. Execution is delegated
    # to AgentRuntime which manages the ReAct loop, planning, and step processing.
    #
    # == Architecture
    #
    # The Agent class follows a separation of concerns pattern:
    #
    # - *Agent* owns configuration, tools, model, and prompt generation
    # - *AgentRuntime* owns execution state, ReAct loop, and step processing
    # - *Executor* owns sandboxed code execution
    # - *AgentMemory* owns conversation history and context management
    #
    # == Execution Modes
    #
    # Agents support three execution modes:
    #
    # 1. *Synchronous* (+run+) - Returns final result, auto-approves control requests
    # 2. *Streaming* (+run(stream: true)+) - Returns Enumerator yielding steps
    # 3. *Fiber* (+run_fiber+) - Returns Fiber for bidirectional control
    #
    # @example Minimal agent with mock model (for testing)
    #   model = Smolagents::Testing::MockModel.new(responses: ["final_answer('4')"])
    #   agent = Smolagents::Agents::Agent.new(
    #     model: model,
    #     tools: [Smolagents::Tools::FinalAnswerTool.new]
    #   )
    #   result = agent.run("What is 2+2?")
    #   result.success?
    #   # => true
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search, :web)
    #     .as(:researcher)
    #     .max_steps(15)
    #     .build
    #
    # @example Streaming execution
    #   agent.run("Search for Ruby 4.0", stream: true).each do |step|
    #     puts "Step #{step.step_number}: #{step.observations}"
    #   end
    #
    # @example Fiber execution with user input
    #   fiber = agent.run_fiber("Which file to process?")
    #   loop do
    #     case fiber.resume
    #     in Types::ControlRequests::UserInput => req
    #       response = Types::ControlRequests::Response.respond(
    #         request_id: req.id,
    #         value: "config.yml"
    #       )
    #       fiber.resume(response)
    #     in Types::RunResult => result
    #       break result
    #     end
    #   end
    #
    # @see AgentRuntime For execution logic and ReAct loop
    # @see Executors::LocalRuby Code execution sandbox
    # @see Runtime::AgentMemory Conversation history management
    # @see Types::RunResult The result type from agent runs
    # @see Types::ActionStep Individual step in the ReAct loop
    class Agent
      include Events::Consumer
      include Concerns::Monitorable
      include Concerns::ManagedAgents
      include Persistence::Serializable

      # The execution runtime that manages the ReAct loop.
      #
      # @return [AgentRuntime] The execution runtime
      # @see AgentRuntime
      attr_reader :runtime

      # The code executor for sandboxed Ruby execution.
      #
      # @return [Executors::Executor] The code executor (sandbox)
      # @see Executors::LocalRuby Default executor
      # @see Executors::Docker Docker-based executor
      # @see Executors::Ractor Ractor-based executor
      attr_reader :executor

      # List of Ruby libraries allowed for require statements in agent code.
      #
      # @return [Array<String>] Allowed Ruby libraries (e.g., ["json", "uri"])
      # @example
      #   agent.authorized_imports
      #   # => ["json", "uri", "date"]
      attr_reader :authorized_imports

      # Tools available to the agent, keyed by tool name.
      #
      # Includes both explicitly provided tools and tools generated from
      # managed agents (sub-agents).
      #
      # @return [Hash{String => Tools::Tool}] Available tools by name
      # @example
      #   agent.tools.keys
      #   # => ["final_answer", "search", "web_browser"]
      # @see Tools::Tool Base tool class
      attr_reader :tools

      # The LLM model used for code generation.
      #
      # @return [Models::Model] The LLM model
      # @see Models::OpenAIModel OpenAI-compatible models
      # @see Models::AnthropicModel Anthropic Claude models
      attr_reader :model

      # Conversation history and step tracking.
      #
      # @return [Runtime::AgentMemory] Agent memory
      # @see Runtime::AgentMemory
      attr_reader :memory

      # Maximum number of steps before the agent stops.
      #
      # @return [Integer] Maximum steps (default from configuration)
      # @example
      #   agent.max_steps
      #   # => 10
      attr_reader :max_steps

      # Logger for agent operations.
      #
      # @return [Logging::Logger, Logging::NullLogger] Logger instance
      # @see Logging::NullLogger Default no-op logger
      attr_reader :logger

      # Creates a new agent.
      #
      # Initializes the agent with a model, tools, and optional configuration.
      # The agent sets up its runtime, executor, and memory based on the provided
      # parameters and global configuration defaults.
      #
      # @param model [Models::Model] The LLM model for generating code
      # @param tools [Array<Tools::Tool>] Tools available to the agent
      # @param config [Types::AgentConfig, nil] Configuration object (uses defaults if nil)
      # @param executor [Executors::Executor, nil] Code executor (default: LocalRuby)
      # @param managed_agents [Hash{String => Agent}, nil] Sub-agents for delegation
      # @param logger [Logging::Logger, nil] Custom logger instance (default: NullLogger)
      #
      # @return [Agent] A new agent instance
      #
      # @example Creating an agent with minimal configuration
      #   model = Smolagents::Testing::MockModel.new(responses: ["final_answer('done')"])
      #   agent = Smolagents::Agents::Agent.new(
      #     model: model,
      #     tools: [Smolagents::Tools::FinalAnswerTool.new]
      #   )
      #
      # @example Creating an agent with custom configuration
      #   config = Types::AgentConfig.new(max_steps: 20, authorized_imports: ["json"])
      #   agent = Agent.new(model: model, tools: tools, config: config)
      #
      # @example Creating an agent with managed sub-agents
      #   researcher = Agent.new(model: model, tools: [search_tool])
      #   coordinator = Agent.new(
      #     model: model,
      #     tools: [final_answer],
      #     managed_agents: { "researcher" => researcher }
      #   )
      #
      # @see Types::AgentConfig For configuration options
      # @see Executors::LocalRuby Default executor
      def initialize(model:, tools:, config: nil, executor: nil, managed_agents: nil, logger: nil)
        agent_config = config || Types::AgentConfig.default
        initialize_core(model:, executor:, logger:, agent_config:)
        initialize_tools(tools, managed_agents)
        initialize_memory_and_runtime(agent_config)
      end

      # Connects the agent to an event queue for observability.
      #
      # Events from the agent and its runtime will be published to the queue.
      # This enables monitoring, logging, and integration with external systems.
      #
      # @param queue [Events::Queue] The event queue to connect to
      # @return [self] The agent instance for chaining
      #
      # @example Connecting to an event queue
      #   queue = Events::Queue.new
      #   agent.connect_to(queue)
      #   queue.subscribe { |event| puts event.class.name }
      #
      # @see Events::Consumer For event consumption details
      def connect_to(queue)
        super
        @runtime&.connect_to(queue)
        self
      end

      # Runs the agent on a task.
      #
      # Executes the agent's ReAct loop until a final answer is produced,
      # max steps is reached, or an error occurs. The execution mode depends
      # on the +stream+ parameter.
      #
      # @param task [String] The task to accomplish
      # @param stream [Boolean] If true, returns Enumerator yielding ActionStep objects
      # @param reset [Boolean] If true, resets memory before running (default: true)
      # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
      # @param additional_prompting [String, nil] Extra instructions appended to task
      #
      # @return [Types::RunResult] When stream is false, the final result
      # @return [Enumerator<Types::ActionStep>] When stream is true, step enumerator
      #
      # @example Synchronous execution
      #   result = agent.run("What is 2+2?")
      #   if result.success?
      #     puts result.output
      #   end
      #
      # @example Streaming execution
      #   agent.run("Search for Ruby news", stream: true).each do |step|
      #     puts "Step #{step.step_number}"
      #     puts "Observations: #{step.observations}"
      #   end
      #
      # @example With images (multimodal)
      #   result = agent.run(
      #     "Describe this image",
      #     images: ["/path/to/image.png"]
      #   )
      #
      # @example With additional prompting
      #   result = agent.run(
      #     "Find information about Ruby",
      #     additional_prompting: "Focus on version 4.0 features"
      #   )
      #
      # @see #run_fiber For bidirectional control flow
      # @see Types::RunResult For result structure
      # @see Types::ActionStep For step structure
      def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
        @runtime.run(task, stream:, reset:, images:, additional_prompting:)
      end

      # Fiber-based execution with bidirectional control.
      #
      # Returns a Fiber that yields control back to the caller at each step
      # and when user input or confirmation is needed. This enables interactive
      # agent execution where the caller can inspect progress and respond to
      # control requests.
      #
      # The Fiber yields three types of values:
      # - +Types::ActionStep+ - A completed step (resume to continue)
      # - +Types::ControlRequests::Request+ - Needs response (resume with Response)
      # - +Types::RunResult+ - Execution complete (Fiber is dead)
      #
      # @param task [String] The task to accomplish
      # @param reset [Boolean] If true, resets memory before running (default: true)
      # @param images [Array<String>, nil] Image paths/URLs for multimodal tasks
      # @param additional_prompting [String, nil] Extra instructions appended to task
      #
      # @return [Fiber] Fiber that yields ActionStep, ControlRequest, or RunResult
      #
      # @example Basic fiber execution
      #   fiber = agent.run_fiber("What is 2+2?")
      #   loop do
      #     result = fiber.resume
      #     case result
      #     when Types::ActionStep
      #       puts "Completed step #{result.step_number}"
      #     when Types::RunResult
      #       puts "Final answer: #{result.output}"
      #       break
      #     end
      #   end
      #
      # @example Handling user input requests
      #   fiber = agent.run_fiber("Process a file")
      #   loop do
      #     case fiber.resume
      #     in Types::ControlRequests::UserInput => req
      #       answer = prompt_user(req.prompt, req.options)
      #       response = Types::ControlRequests::Response.respond(
      #         request_id: req.id,
      #         value: answer
      #       )
      #       fiber.resume(response)
      #     in Types::ControlRequests::Confirmation => req
      #       approved = confirm_action(req.description)
      #       response = approved ?
      #         Types::ControlRequests::Response.approve(request_id: req.id) :
      #         Types::ControlRequests::Response.deny(request_id: req.id)
      #       fiber.resume(response)
      #     in Types::RunResult => result
      #       break result
      #     end
      #   end
      #
      # @see Types::ControlRequests For control request types
      # @see Types::ControlRequests::Response For response construction
      # @see #run For synchronous execution
      def run_fiber(task, reset: true, images: nil, additional_prompting: nil)
        @runtime.run_fiber(task, reset:, images:, additional_prompting:)
      end

      # Executes a single step in the ReAct loop.
      #
      # Useful for testing or when you need fine-grained control over
      # execution. Each step involves:
      # 1. Generating code from the model based on current memory
      # 2. Parsing and validating the generated code
      # 3. Executing the code in the sandbox
      # 4. Recording observations in memory
      #
      # @param task [String] The current task (for context)
      # @param step_number [Integer] Current step number (0-indexed)
      #
      # @return [Types::ActionStep] The completed action step with observations
      #
      # @example Manual step execution
      #   agent.memory.add_task("Calculate fibonacci(10)")
      #   step = agent.step("Calculate fibonacci(10)", step_number: 0)
      #   puts step.observations
      #   puts step.code_action
      #
      # @see Types::ActionStep For step structure
      # @see #run For complete task execution
      def step(task, step_number: 0)
        @runtime.step(task, step_number:)
      end

      # Returns the complete system prompt for the agent.
      #
      # The system prompt combines:
      # - Base code agent instructions
      # - Tool descriptions and usage patterns
      # - Managed agent (sub-agent) descriptions
      # - Custom instructions from configuration
      # - Capability descriptions showing available tools
      #
      # @return [String] Complete system prompt sent to the model
      #
      # @example Inspecting the system prompt
      #   puts agent.system_prompt.lines.first(10).join
      #
      # @see Prompts::CodeAgent For base prompt generation
      def system_prompt
        base_prompt = Prompts::CodeAgent.generate(
          tools: @tools.values.map { |t| t.format_for(:code) },
          team: managed_agent_descriptions,
          authorized_imports: @authorized_imports,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool usage patterns.
      #
      # Creates a supplementary prompt section that describes available
      # capabilities based on registered tools and managed agents. This
      # helps the model understand what actions are available.
      #
      # @return [String] Capabilities prompt addendum (may be empty)
      #
      # @example Getting capabilities
      #   caps = agent.capabilities_prompt
      #   puts caps unless caps.empty?
      #
      # @see Prompts.generate_capabilities For generation logic
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools: @tools,
          managed_agents: @managed_agents,
          agent_type: :code
        )
      end

      # Template path for custom prompts.
      #
      # Override in subclasses to provide custom prompt templates.
      # Returns nil by default (uses built-in prompts).
      #
      # @return [String, nil] Path to custom prompt template, or nil
      # @api private
      def template_path = nil

      # Returns the runtime's internal state hash.
      #
      # @return [Hash] Mutable state hash from the runtime
      # @api private
      def state = @runtime.instance_variable_get(:@state)

      # Returns the planning interval (steps between replanning).
      #
      # @return [Integer, nil] Steps between planning phases, or nil if disabled
      # @see Concerns::Planning For planning behavior
      def planning_interval = @runtime.planning_interval

      # Returns the planning templates configuration.
      #
      # @return [Hash, nil] Planning prompt templates
      # @see Concerns::Planning For planning behavior
      def planning_templates = @runtime.planning_templates

      private

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

      def initialize_tools(tools, managed_agents)
        setup_managed_agents(managed_agents)
        @tools = tools_with_managed_agents(tools)
        @executor.send_tools(@tools)
      end

      def initialize_memory_and_runtime(agent_config)
        mem_config = agent_config.memory_config || Types::MemoryConfig.default
        @memory = AgentMemory.new(system_prompt, config: mem_config)
        @runtime = build_runtime(agent_config)
        @runtime.event_queue = @event_queue if @event_queue
      end

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

      # @api private
      # Delegate plan_context access to runtime for compatibility
      def plan_context = @runtime.send(:plan_context)
    end

    # Factory method to create an agent.
    #
    # Convenience method equivalent to +Agent.new+.
    #
    # @param model [Models::Model] The LLM model
    # @param tools [Array<Tools::Tool>] Tools available (default: [])
    # @option options [Types::AgentConfig] :config Configuration object
    # @option options [Executors::Executor] :executor Code executor
    # @option options [Hash{String => Agent}] :managed_agents Sub-agents
    # @option options [Logging::Logger] :logger Custom logger
    #
    # @return [Agent] A new agent instance
    #
    # @example Creating an agent
    #   agent = Smolagents::Agents.create(model: model, tools: [tool])
    #
    # @see Agent#initialize For full parameter documentation
    def self.create(model:, tools: [], **) = Agent.new(model:, tools:, **)

    # Creates a code agent (alias for create).
    #
    # @deprecated Use {.create} instead
    # @param model [Models::Model] The LLM model
    # @param tools [Array<Tools::Tool>] Tools available (default: [])
    # @option options [Types::AgentConfig] :config Configuration object
    # @option options [Executors::Executor] :executor Code executor
    # @return [Agent] A new agent instance
    def self.code(model:, tools: [], **) = Agent.new(model:, tools:, **)
  end
end
