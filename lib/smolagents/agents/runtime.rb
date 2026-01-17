module Smolagents
  module Agents
    # Execution runtime for agents.
    #
    # AgentRuntime handles the ReAct (Reasoning and Acting) loop, code execution,
    # planning, and evaluation. It is created by Agent and receives delegated
    # +run()+ and +step()+ calls.
    #
    # == Separation of Concerns
    #
    # This separation keeps responsibilities clear:
    # - *Agent* owns configuration, tools, model, and prompt generation
    # - *AgentRuntime* owns execution state, ReAct loop, and step processing
    #
    # == Included Concerns
    #
    # The runtime includes several mixins that provide specific functionality:
    #
    # - *ReActLoop::Core* - Main execution loop and run entry points
    # - *ReActLoop::Control* - Fiber bidirectional control (user input, confirmations)
    # - *ReActLoop::Repetition* - Loop detection to prevent infinite loops
    # - *Evaluation* - Metacognition phase for self-assessment
    # - *StepExecution* - Individual step processing
    # - *Planning* - Periodic replanning during long runs
    # - *CodeExecution* - Code generation and sandbox execution
    #
    # == ReAct Loop
    #
    # The ReAct pattern alternates between:
    # 1. *Reasoning* - Model generates code based on task and observations
    # 2. *Acting* - Code executes in sandbox, producing observations
    # 3. *Repeat* - Until final_answer called or max_steps reached
    #
    # @example Direct usage (internal)
    #   runtime = AgentRuntime.new(
    #     model: model, tools: tools, executor: executor,
    #     memory: memory, max_steps: 10, logger: logger
    #   )
    #   result = runtime.run("Find Ruby 4.0 features")
    #   result.success?
    #   # => true
    #
    # @example Running with planning enabled
    #   runtime = AgentRuntime.new(
    #     model: model, tools: tools, executor: executor,
    #     memory: memory, max_steps: 20, logger: logger,
    #     planning_interval: 5  # Replan every 5 steps
    #   )
    #   result = runtime.run("Complex multi-step task")
    #
    # @see Agent For the public API
    # @see Concerns::ReActLoop For execution loop details
    # @see Concerns::Planning For planning behavior
    # @see Concerns::Evaluation For metacognition
    class AgentRuntime
      include Concerns::Monitorable
      include Concerns::ReActLoop
      # Opt-in ReActLoop features for full agent functionality
      include Concerns::ReActLoop::Control    # Fiber bidirectional control
      include Concerns::ReActLoop::Repetition # Loop detection
      include Concerns::Evaluation            # Metacognition phase
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::CodeExecution

      # The code executor for sandboxed Ruby execution.
      #
      # @return [Executors::Executor] The code executor (sandbox)
      # @see Executors::LocalRuby Default executor
      # @see Executors::Docker Docker-based executor
      attr_reader :executor

      # List of Ruby libraries allowed for require statements in agent code.
      #
      # @return [Array<String>] Allowed Ruby libraries (e.g., ["json", "uri"])
      # @example
      #   runtime.authorized_imports
      #   # => ["json", "uri", "date"]
      attr_reader :authorized_imports

      # Creates a new runtime.
      #
      # Initializes the execution runtime with all necessary components for
      # running the ReAct loop. The runtime manages execution state, planning,
      # evaluation, and step processing.
      #
      # @param model [Models::Model] The LLM model for code generation
      # @param tools [Hash{String => Tools::Tool}] Available tools (name => tool)
      # @param executor [Executors::Executor] Code executor for sandbox execution
      # @param memory [Runtime::AgentMemory] Agent memory for conversation history
      # @param max_steps [Integer] Maximum steps before stopping
      # @param logger [Logging::Logger] Logger instance for operation logging
      # @param custom_instructions [String, nil] Additional instructions appended to prompts
      # @param planning_interval [Integer, nil] Steps between replanning (nil to disable)
      # @param planning_templates [Hash, nil] Custom planning prompt templates
      # @param spawn_config [Types::SpawnConfig, nil] Configuration for spawning child agents
      # @param evaluation_enabled [Boolean] Enable metacognition phase (default: false)
      # @param authorized_imports [Array<String>] Allowed require paths for agent code
      #
      # @return [AgentRuntime] A new runtime instance
      #
      # @example Creating a runtime
      #   runtime = AgentRuntime.new(
      #     model: model,
      #     tools: { "search" => search_tool, "final_answer" => final_answer_tool },
      #     executor: Executors::LocalRuby.new,
      #     memory: Runtime::AgentMemory.new("You are a helpful assistant"),
      #     max_steps: 10,
      #     logger: Logging::NullLogger.instance
      #   )
      #
      # @example With planning enabled
      #   runtime = AgentRuntime.new(
      #     model: model,
      #     tools: tools,
      #     executor: executor,
      #     memory: memory,
      #     max_steps: 20,
      #     logger: logger,
      #     planning_interval: 5,
      #     planning_templates: { initial: "Plan the task...", update: "Update plan..." }
      #   )
      #
      # @see Agent#initialize Usually created via Agent, not directly
      def initialize(
        model:, tools:, executor:, memory:, max_steps:, logger:,
        custom_instructions: nil, planning_interval: nil, planning_templates: nil,
        spawn_config: nil, evaluation_enabled: false, authorized_imports: nil
      )
        assign_core(model:, tools:, executor:, memory:, max_steps:, logger:)
        assign_optional(custom_instructions:, spawn_config:, authorized_imports:)
        initialize_planning(planning_interval:, planning_templates:)
        initialize_evaluation(evaluation_enabled:)
        setup_consumer
      end

      # Executes a single step in the ReAct loop.
      #
      # Performs one iteration of the ReAct pattern:
      # 1. Calls the model to generate code based on current memory
      # 2. Parses and validates the generated code
      # 3. Executes the code in the sandbox
      # 4. Records observations and updates memory
      #
      # @param _task [String] The current task (used for context, may be ignored)
      # @param step_number [Integer] Current step number (0-indexed)
      #
      # @return [Types::ActionStep] The completed action step with observations
      #
      # @example Executing a single step
      #   step = runtime.step("Calculate 2+2", step_number: 0)
      #   step.step_number
      #   # => 0
      #   step.observations
      #   # => "4"
      #
      # @see Types::ActionStep For step structure
      # @see Concerns::StepExecution For step execution details
      def step(_task, step_number: 0)
        with_step_timing(step_number:) { |action_step| execute_step(action_step) }
      end

      # Converts memory to LLM message format.
      #
      # Used internally by CodeExecution to prepare messages for the model.
      # Delegates to AgentMemory#to_messages.
      #
      # @param summary_mode [Boolean] If true, uses condensed message format
      #
      # @return [Array<Types::ChatMessage>] Messages suitable for LLM context
      #
      # @example Getting messages for model
      #   messages = runtime.write_memory_to_messages
      #   messages.first.role
      #   # => :system
      #
      # @see Runtime::AgentMemory#to_messages For message formatting
      # @api private
      def write_memory_to_messages(summary_mode: false)
        @memory.to_messages(summary_mode:)
      end

      private

      def assign_core(model:, tools:, executor:, memory:, max_steps:, logger:)
        @model = model
        @tools = tools
        @executor = executor
        @memory = memory
        @max_steps = max_steps
        @logger = logger
      end

      def assign_optional(custom_instructions:, spawn_config:, authorized_imports:)
        @custom_instructions = custom_instructions
        @spawn_config = spawn_config
        @authorized_imports = authorized_imports || []
        @state = {}
      end
    end
  end
end
