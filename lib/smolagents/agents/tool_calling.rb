module Smolagents
  module Agents
    # Agent that uses JSON tool calling format for actions.
    #
    # ToolCalling agents leverage the native function/tool calling capabilities
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
    #   agent = ToolCalling.new(
    #     model: OpenAIModel.new(model_id: "gpt-4"),
    #     tools: [WebSearchTool.new, CalculatorTool.new]
    #   )
    #   result = agent.run("Search for Ruby programming tutorials")
    #
    # @example With parallel tool execution
    #   agent = ToolCalling.new(
    #     model: my_model,
    #     tools: my_tools,
    #     max_tool_threads: 4  # Execute up to 4 tools in parallel
    #   )
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { my_model }
    #     .tools(:web_search, :calculator)
    #     .max_steps(10)
    #     .build
    #
    # @see Agent Base class
    # @see Code Alternative agent that writes Ruby code
    class ToolCalling < Agent
      include Concerns::ToolExecution
      include Concerns::AsyncTools

      # Creates a new ToolCalling agent.
      #
      # Initializes a ToolCalling agent that uses JSON tool calling format. The agent
      # asks the model to return structured JSON describing which tools to call and with
      # what arguments. This is the native tool calling format supported by OpenAI,
      # Anthropic, and other modern LLMs.
      #
      # @param tools [Array<Tool>] Tools available to the agent. The agent will request
      #   that the model choose from these tools via JSON format.
      # @param model [Model] The LLM model with tool calling support. Should be one of:
      #   - OpenAI models (gpt-4, gpt-3.5-turbo, etc.)
      #   - Anthropic models (claude-3, etc.)
      #   - Other providers that support function_calling or tool_use
      # @param max_tool_threads [Integer, nil] Maximum number of threads for parallel
      #   tool execution. When nil, uses DEFAULT_MAX_TOOL_THREADS (typically 4).
      #   Set to 1 for sequential execution, higher for more parallelism.
      # @param kwargs [Hash] Additional options passed to Agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping (default: 10)
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      # @option kwargs [Integer] :planning_interval Steps between planning phases (nil = disabled)
      # @option kwargs [Hash<String, Agent>] :managed_agents Sub-agents for delegation
      # @option kwargs [Proc] :on_step Callback after each step
      # @option kwargs [Proc] :on_error Callback when errors occur
      #
      # @example Simple web search agent
      #   agent = ToolCalling.new(
      #     model: OpenAIModel.new(model_id: "gpt-4"),
      #     tools: [WebSearchTool.new, VisitWebpageTool.new]
      #   )
      #   result = agent.run("Find the latest Ruby release notes")
      #
      # @example With parallel tool execution
      #   agent = ToolCalling.new(
      #     model: my_model,
      #     tools: [search1, search2, search3],
      #     max_tool_threads: 6  # Execute up to 6 tools in parallel
      #   )
      #   result = agent.run("Search multiple sources simultaneously")
      #
      # @example With research specialization
      #   agent = ToolCalling.new(
      #     model: my_model,
      #     tools: [
      #       DuckDuckGoSearchTool.new,
      #       VisitWebpageTool.new,
      #       WikipediaSearchTool.new,
      #       FinalAnswerTool.new
      #     ],
      #     max_steps: 15,
      #     custom_instructions: "Cross-reference information across multiple sources"
      #   )
      #
      # @raise [ArgumentError] If max_tool_threads is not a positive integer
      # @raise [ArgumentError] If model doesn't support tool calling
      #
      # @see execute_step Implemented to parse and execute JSON tool calls
      # @see Concerns::ToolExecution Module providing tool execution capabilities
      # @see Concerns::AsyncTools Module providing parallel tool execution
      def initialize(tools:, model:, max_tool_threads: nil, **)
        super(tools: tools, model: model, **)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end
    end
  end
end
