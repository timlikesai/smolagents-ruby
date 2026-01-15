module Smolagents
  module Agents
    # Agent that writes Ruby code to accomplish tasks.
    #
    # Code agents generate Ruby code snippets that call tools and perform
    # computations. This allows for complex multi-step reasoning with
    # conditionals, loops, and variable storage within a single step.
    #
    # The generated code is executed in a sandboxed environment with
    # configurable safety limits (timeout, max operations, authorized imports).
    #
    # Advantages over Tool:
    # - Can use loops, conditionals, and Ruby constructs
    # - Can store intermediate results in variables
    # - Can call multiple tools in a single step
    # - More expressive for complex computations
    #
    # Trade-offs:
    # - Requires model capable of generating valid Ruby code
    # - Slightly higher risk of code injection (mitigated by sandbox)
    # - May be slower due to code parsing overhead
    #
    # @example Basic usage
    #   agent = Code.new(
    #     model: OpenAIModel.lm_studio("gemma-3n-e4b"),
    #     tools: [CalculatorTool.new, WebSearchTool.new]
    #   )
    #   result = agent.run("Calculate the factorial of 10")
    #
    # @example With custom executor
    #   agent = Code.new(
    #     model: my_model,
    #     tools: my_tools,
    #     executor: LocalRubyExecutor.new(max_operations: 10_000),
    #     authorized_imports: %w[json yaml csv]
    #   )
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent
    #     .with(:code)
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search)
    #     .max_steps(15)
    #     .build
    #
    # @see Agent Base class
    # @see Tool Alternative agent using JSON tool calls
    # @see LocalRubyExecutor Code execution sandbox
    class Code < Agent
      include Concerns::CodeExecution

      # Creates a new Code agent.
      #
      # Initializes a Code agent that generates and executes Ruby code to accomplish
      # tasks. The agent writes actual Ruby code snippets that can use tools, perform
      # calculations, use Ruby control flow, and manipulate data.
      #
      # @param tools [Array<Tool>] Tools available to the agent. Each tool becomes
      #   a callable method within the code execution environment.
      # @param model [Model] The LLM model for generating code. Should be capable of
      #   writing valid Ruby code (GPT-4, Claude, etc.). Local models may struggle.
      # @param executor [Executor, nil] Custom code executor for running generated code.
      #   Default is LocalRubyExecutor which provides sandboxing and safety limits.
      # @param authorized_imports [Array<String>, nil] Allowed Ruby libraries for code execution.
      #   Examples: %w[json yaml csv]. If nil, a safe default set is used. Only libraries
      #   in this list can be imported with +require+ in generated code.
      # @param kwargs [Hash] Additional options passed to Agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping (default: 10)
      # @option kwargs [Integer] :timeout_per_step Timeout in seconds for each code execution (default: 30)
      # @option kwargs [Integer] :max_operations Maximum operations before sandbox stops execution (default: 1_000_000)
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      # @option kwargs [Integer] :planning_interval Steps between planning phases (nil = disabled)
      # @option kwargs [Hash<String, Agent>] :managed_agents Sub-agents for delegation
      #
      # @example Simple calculation agent
      #   agent = Code.new(
      #     model: OpenAIModel.lm_studio("gemma-3n-e4b"),
      #     tools: [CalculatorTool.new]
      #   )
      #   result = agent.run("Calculate the factorial of 10")
      #
      # @example With safe imports for data processing
      #   agent = Code.new(
      #     model: my_model,
      #     tools: [WebSearchTool.new, RubyInterpreterTool.new],
      #     authorized_imports: %w[json csv time],
      #     max_steps: 15
      #   )
      #   result = agent.run("Fetch CSV data and analyze it")
      #
      # @example With custom executor limits
      #   agent = Code.new(
      #     model: my_model,
      #     tools: my_tools,
      #     executor: LocalRubyExecutor.new(
      #       timeout: 60,
      #       max_operations: 5_000_000
      #     )
      #   )
      #
      # @raise [ArgumentError] If executor is provided but not an Executor instance
      # @raise [ArgumentError] If authorized_imports contains invalid library names
      #
      # @see execute_step Implemented to parse and execute Ruby code
      # @see Concerns::CodeExecution Module providing code execution capabilities
      # @see LocalRubyExecutor Default executor with sandboxing
      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **)
        setup_code_execution(executor:, authorized_imports:)
        super(tools:, model:, **)
        finalize_code_execution
      end
    end
  end
end
