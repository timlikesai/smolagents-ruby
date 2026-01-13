module Smolagents
  # Agent namespace containing all agent implementations.
  #
  # Provides factory methods for creating agents:
  # - {Agents.code} - Creates a CodeAgent that writes Ruby code
  # - {Agents.tool_calling} - Creates a ToolCallingAgent using JSON tool calls
  #
  # @example Creating agents via factory methods
  #   agent = Smolagents::Agents.code(model: my_model, tools: [my_tool])
  #   agent = Smolagents::Agents.tool_calling(model: my_model, tools: [my_tool])
  #
  # @example Creating agents via AgentBuilder DSL
  #   agent = Smolagents.agent(:code)
  #     .model { my_model }
  #     .tools(:web_search, :calculator)
  #     .max_steps(15)
  #     .build
  module Agents
    # Abstract base class for all agent implementations.
    #
    # Agent provides the common infrastructure for running agentic loops:
    # - ReAct (Reason + Act) loop for multi-step problem solving
    # - Tool management and execution
    # - Memory for tracking conversation history and steps
    # - Planning capabilities for complex tasks
    # - Managed sub-agents for hierarchical agent systems
    # - Persistence for saving/loading agent configurations
    #
    # Subclasses must implement:
    # - {#system_prompt} - Returns the system prompt for the agent
    # - {#execute_step} - Executes a single reasoning/action step
    #
    # @example Using a concrete agent
    #   agent = Smolagents::Agents::Code.new(
    #     model: my_model,
    #     tools: [calculator, search],
    #     max_steps: 10
    #   )
    #   result = agent.run("What is 42 * 17?")
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent(:code)
    #     .model { OpenAIModel.new(model_id: "gpt-4") }
    #     .tools(:calculator)
    #     .max_steps(10)
    #     .on_step { |step| puts "Step #{step.step_number}" }
    #     .build
    #
    # @abstract Subclass and implement {#system_prompt} and {#execute_step}
    # @see Code Agent that writes Ruby code for actions
    # @see ToolCalling Agent that uses JSON tool calling format
    class Agent
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Persistence::Serializable

      # Creates a new agent instance.
      #
      # Initializes the agent with the provided tools and model, setting up
      # the ReAct loop infrastructure, memory management, and monitoring.
      #
      # @param tools [Array<Tool>] Tools available to the agent. Each tool must
      #   have a unique name, description, inputs schema, and output type.
      # @param model [Model] The LLM model for generating responses. Should be
      #   configured with appropriate API keys or connection details.
      # @param kwargs [Hash] Additional options passed to setup_agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping the agent loop
      #   (default: 10). Prevents infinite loops in multi-step tasks.
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      #   to guide the agent behavior beyond the default system prompt.
      # @option kwargs [Integer] :planning_interval Steps between planning phases (nil = disabled).
      #   When set, the agent analyzes progress and replans every N steps.
      # @option kwargs [Hash<String, Agent>] :managed_agents Sub-agents this agent can
      #   delegate to. Keys are agent names, values are Agent instances.
      # @option kwargs [Proc] :on_step Callback function called after each step
      #   with the completed ActionStep.
      # @option kwargs [Proc] :on_error Callback function called when an error occurs
      #   with the error exception.
      #
      # @example Minimal agent setup
      #   agent = Agent.new(model: my_model, tools: [calculator, search])
      #
      # @example With planning and callbacks
      #   agent = Agent.new(
      #     model: my_model,
      #     tools: [search, calculator],
      #     max_steps: 20,
      #     planning_interval: 5,
      #     on_step: ->(step) { puts "Step #{step.step_number}" }
      #   )
      #
      # @see run For executing tasks with the agent
      # @see step For executing a single step
      def initialize(tools:, model:, **)
        setup_agent(tools: tools, model: model, **)
      end

      # Executes a single step in the ReAct loop.
      #
      # Runs one iteration of the agent's reasoning and action cycle. The agent
      # generates a response from the model, parses actions, executes tools, and
      # collects observations. This is the core loop that repeats until a final
      # answer is reached or max_steps is exceeded.
      #
      # @param task [String] The current task being worked on. Used to maintain
      #   context in the ReAct loop. Usually passed from {#run}.
      # @param step_number [Integer] Current step number (0-indexed). Used for
      #   tracking progress and timing measurements.
      # @return [ActionStep] The completed action step containing:
      #   - Agent thoughts and reasoning
      #   - Tool calls made in this step
      #   - Observations from tool execution
      #   - Step timing and token usage
      #
      # @raise [Timeout::Error] If the step execution exceeds the configured timeout
      # @raise [MaxStepsExceeded] If this step reaches the maximum step limit
      #
      # @example Running multiple steps manually
      #   agent = my_agent
      #   step1 = agent.step("Find information about Ruby", step_number: 0)
      #   step2 = agent.step("Find information about Ruby", step_number: 1)
      #   # Each step advances the ReAct loop
      #
      # @see #run For the full agent execution with automatic looping
      # @see ActionStep For the structure of returned steps
      # @see #execute_step Implemented by subclasses to define action logic
      def step(_task, step_number: 0)
        with_step_timing(step_number: step_number) { |action_step| execute_step(action_step) }
      end

      # Returns the system prompt for this agent type.
      #
      # The system prompt defines the agent's identity, capabilities, constraints,
      # and reasoning approach. It's combined with the task description and memory
      # history to form the complete prompt sent to the LLM.
      #
      # Different agent types (Code, ToolCalling, etc.) provide specialized system
      # prompts that guide the model toward the appropriate response format.
      #
      # @return [String] The system prompt with detailed instructions for the agent.
      #   Must include instructions on what the agent can do, what tools are available,
      #   and what format to use for responses.
      #
      # @raise [NotImplementedError] Must be implemented by subclasses. Base Agent
      #   is abstract and cannot be used directly.
      #
      # @example In a Code agent
      #   # Returns prompt like: "You are an agent that writes Ruby code to solve tasks.
      #   # Use the available tools by calling them with proper Ruby syntax..."
      #
      # @example In a ToolCalling agent
      #   # Returns prompt like: "You are an agent that uses JSON tool calls.
      #   # Format your response as JSON with a 'tool' field..."
      #
      # @see Code#system_prompt Code agent implementation
      # @see ToolCalling#system_prompt Tool calling agent implementation
      # @abstract Subclass and implement to define agent behavior
      def system_prompt = raise(NotImplementedError)

      # Executes the logic for a single step.
      #
      # This is the core method that implements the agent's reasoning and action
      # logic for one iteration. It receives an ActionStep object that has been
      # populated with the model's response, and must:
      #
      # 1. Parse the model's response into tool calls or code
      # 2. Execute those tools or code in a controlled manner
      # 3. Collect observations and add them to the action_step
      # 4. Update the action_step state accordingly
      #
      # The action_step is modified in-place by this method.
      #
      # @param action_step [ActionStep] The action step to execute. Contains:
      #   - model_output: Raw response from the LLM
      #   - thoughts: Parsed reasoning from the model
      #   - tool_calls: Parsed tool calls (populated by this method)
      #   - observations: Observations from execution (filled by this method)
      #   - state: Current state (updated by this method)
      #
      # @return [void] Modifies action_step in place.
      #
      # @raise [NotImplementedError] Must be implemented by subclasses. Base Agent
      #   is abstract and cannot be used directly.
      # @raise [CodeExecutionError] May be raised by subclasses if execution fails
      #
      # @example For Code agents
      #   # Parses Ruby code from model output and executes it
      #   def execute_step(action_step)
      #     code = extract_code_from_output(action_step.model_output)
      #     result = executor.execute(code)
      #     action_step.observations << result
      #   end
      #
      # @example For ToolCalling agents
      #   # Parses JSON tool calls and executes them
      #   def execute_step(action_step)
      #     calls = parse_tool_calls_from_json(action_step.model_output)
      #     results = execute_tools(calls)
      #     action_step.observations.concat(results)
      #   end
      #
      # @see step Called by the step method
      # @see ActionStep The action step data structure
      # @abstract Subclass and implement to define step execution behavior
      def execute_step(_) = raise(NotImplementedError)
    end

    # Creates a Code agent that writes Ruby code for actions.
    #
    # @param model [Model] The LLM model for generating responses
    # @param tools [Array<Tool>] Tools available to the agent (default: [])
    # @param kwargs [Hash] Additional options passed to Code.new
    # @return [Code] A new Code agent instance
    # @see Code
    def self.code(model:, tools: [], **) = Code.new(model:, tools:, **)

    # Creates a ToolCalling agent that uses JSON tool calling format.
    #
    # @param model [Model] The LLM model for generating responses
    # @param tools [Array<Tool>] Tools available to the agent (default: [])
    # @param kwargs [Hash] Additional options passed to ToolCalling.new
    # @return [ToolCalling] A new ToolCalling agent instance
    # @see ToolCalling
    def self.tool_calling(model:, tools: [], **) = ToolCalling.new(model:, tools:, **)
  end
end
