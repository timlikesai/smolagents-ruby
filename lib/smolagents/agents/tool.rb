module Smolagents
  module Agents
    # Agent that uses JSON tool calling format for actions.
    #
    # Tool agents leverage the native function/tool calling capabilities
    # of modern LLMs. The model generates structured JSON describing which tools
    # to call and with what arguments.
    #
    # Advantages over Code agent:
    # - Works with models that support native tool calling (OpenAI, Anthropic)
    # - More predictable and structured output format
    # - Lower risk of code injection
    # - Parallel tool execution support
    #
    # Trade-offs:
    # - Limited to one tool call per step (unless model supports parallel calls)
    # - Cannot use Ruby constructs like loops or conditionals
    # - Less expressive for complex multi-step computations
    #
    # @example Basic usage
    #   agent = Tool.new(
    #     model: OpenAIModel.lm_studio("gemma-3n-e4b"),
    #     tools: [WebSearchTool.new, CalculatorTool.new]
    #   )
    #   result = agent.run("Search for Ruby programming tutorials")
    #
    # @example With parallel tool execution
    #   agent = Tool.new(
    #     model: my_model,
    #     tools: my_tools,
    #     max_tool_threads: 4  # Execute up to 4 tools in parallel
    #   )
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent(:tool)
    #     .model { my_model }
    #     .tools(:web_search, :calculator)
    #     .max_steps(10)
    #     .build
    #
    # @see Agent Base class
    # @see Code Alternative agent that writes Ruby code
    class Tool < Agent
      include Concerns::ToolExecution
      include Concerns::AsyncTools

      # Creates a new Tool agent.
      #
      # Initializes a Tool agent that uses JSON tool calling format. The agent
      # asks the model to return structured JSON describing which tools to call
      # and with what arguments.
      #
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] The LLM model with tool calling support
      # @param max_tool_threads [Integer, nil] Maximum threads for parallel execution
      # @param kwargs [Hash] Additional options passed to Agent
      #
      # @example Simple web search agent
      #   agent = Tool.new(
      #     model: OpenAIModel.lm_studio("gemma-3n-e4b"),
      #     tools: [WebSearchTool.new, VisitWebpageTool.new]
      #   )
      #   result = agent.run("Find the latest Ruby release notes")
      #
      # @see Concerns::ToolExecution Module providing tool execution
      # @see Concerns::AsyncTools Module providing parallel execution
      def initialize(tools:, model:, max_tool_threads: nil, **)
        super(tools:, model:, **)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end
    end
  end
end
