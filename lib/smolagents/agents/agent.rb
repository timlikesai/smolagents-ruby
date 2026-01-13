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
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] The LLM model for generating responses
      # @param kwargs [Hash] Additional options passed to setup_agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping (default: 10)
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      # @option kwargs [Integer] :planning_interval Steps between planning phases (nil = disabled)
      # @option kwargs [Hash<String, Agent>] :managed_agents Sub-agents this agent can delegate to
      def initialize(tools:, model:, **)
        setup_agent(tools: tools, model: model, **)
      end

      # Executes a single step in the ReAct loop.
      #
      # @param task [String] The current task being worked on
      # @param step_number [Integer] Current step number (0-indexed)
      # @return [ActionStep] The completed action step with observations
      def step(_task, step_number: 0)
        with_step_timing(step_number: step_number) { |action_step| execute_step(action_step) }
      end

      # Returns the system prompt for this agent type.
      #
      # @return [String] The system prompt
      # @raise [NotImplementedError] Must be implemented by subclasses
      # @abstract
      def system_prompt = raise(NotImplementedError)

      # Executes the logic for a single step.
      #
      # @param action_step [ActionStep] The action step to execute
      # @return [void]
      # @raise [NotImplementedError] Must be implemented by subclasses
      # @abstract
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
