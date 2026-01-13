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
    # Advantages over ToolCalling:
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
    #     model: OpenAIModel.new(model_id: "gpt-4"),
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
    #   agent = Smolagents.agent(:code)
    #     .model { my_model }
    #     .tools(:calculator, :web_search)
    #     .max_steps(15)
    #     .build
    #
    # @see Agent Base class
    # @see ToolCalling Alternative agent using JSON tool calls
    # @see LocalRubyExecutor Code execution sandbox
    class Code < Agent
      include Concerns::CodeExecution

      # Creates a new Code agent.
      #
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] The LLM model for generating code
      # @param executor [Executor, nil] Custom code executor (default: LocalRubyExecutor)
      # @param authorized_imports [Array<String>, nil] Allowed Ruby libraries for code execution
      # @param kwargs [Hash] Additional options passed to Agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping (default: 10)
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        super(tools: tools, model: model, **)
        finalize_code_execution
      end
    end
  end
end
