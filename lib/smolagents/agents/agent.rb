module Smolagents
  # Agent namespace.
  #
  # All agents write Ruby code. There is one agent type.
  #
  # @example Creating an agent
  #   agent = Smolagents.agent
  #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  #     .tools(:search)
  #     .build
  #
  #   result = agent.run("Find the latest Ruby release")
  module Agents
    # An agent that writes Ruby code to accomplish tasks.
    #
    # Agents generate Ruby code that calls tools, performs computations,
    # uses loops/conditionals, and stores intermediate results. Code executes
    # in a sandboxed environment with configurable safety limits.
    #
    # @example Minimal agent
    #   agent = Agent.new(
    #     model: OpenAIModel.lm_studio("gemma-3n-e4b"),
    #     tools: [FinalAnswerTool.new]
    #   )
    #   result = agent.run("What is 2+2?")
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search, :web)
    #     .as(:researcher)
    #     .max_steps(15)
    #     .build
    #
    # @see LocalRubyExecutor Code execution sandbox
    class Agent
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::ManagedAgents
      include Concerns::CodeExecution
      include Persistence::Serializable

      # @return [Executor] The code executor (sandbox)
      attr_reader :executor

      # @return [Array<String>] Allowed Ruby libraries
      attr_reader :authorized_imports

      # Creates a new agent.
      #
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] The LLM model for generating code
      # @param executor [Executor, nil] Code executor (default: LocalRubyExecutor)
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @param max_steps [Integer] Maximum steps before stopping (default: 10)
      # @param custom_instructions [String, nil] Additional system prompt instructions
      # @param planning_interval [Integer, nil] Steps between planning phases
      # @param managed_agents [Hash<String, Agent>] Sub-agents for delegation
      #
      # @example Simple agent
      #   agent = Agent.new(
      #     model: my_model,
      #     tools: [SearchTool.new, FinalAnswerTool.new]
      #   )
      #
      # @example With custom executor
      #   agent = Agent.new(
      #     model: my_model,
      #     tools: my_tools,
      #     executor: LocalRubyExecutor.new(max_operations: 10_000),
      #     authorized_imports: %w[json yaml csv]
      #   )
      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **)
        setup_code_execution(executor:, authorized_imports:)
        setup_agent(tools:, model:, **)
        finalize_code_execution
      end

      # Executes a single step in the ReAct loop.
      #
      # @param task [String] The current task
      # @param step_number [Integer] Current step number (0-indexed)
      # @return [ActionStep] The completed action step
      def step(_task, step_number: 0)
        with_step_timing(step_number:) { |action_step| execute_step(action_step) }
      end

      # Returns the system prompt.
      #
      # Combines the base code agent prompt with tool descriptions
      # and any custom instructions.
      #
      # @return [String] Complete system prompt
      def system_prompt
        base_prompt = Prompts::CodeAgent.generate(
          tools: @tools.values.map(&:to_code_prompt),
          team: managed_agent_descriptions,
          authorized_imports: @authorized_imports,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool usage patterns.
      #
      # @return [String] Capabilities prompt addendum
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools: @tools,
          managed_agents: @managed_agents,
          agent_type: :code
        )
      end

      # Template path for custom prompts.
      #
      # @return [nil] Override in subclasses
      def template_path = nil
    end

    # Factory method to create an agent.
    #
    # @param model [Model] The LLM model
    # @param tools [Array<Tool>] Tools available (default: [])
    # @param kwargs [Hash] Additional options
    # @return [Agent] A new agent instance
    def self.create(model:, tools: [], **) = Agent.new(model:, tools:, **)

    # @deprecated Use {.create} instead
    def self.code(model:, tools: [], **) = Agent.new(model:, tools:, **)
  end
end
