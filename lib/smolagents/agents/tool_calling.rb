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
      # @param tools [Array<Tool>] Tools available to the agent
      # @param model [Model] The LLM model with tool calling support
      # @param max_tool_threads [Integer, nil] Maximum threads for parallel tool execution
      #   (default: DEFAULT_MAX_TOOL_THREADS)
      # @param kwargs [Hash] Additional options passed to Agent
      # @option kwargs [Integer] :max_steps Maximum steps before stopping (default: 10)
      # @option kwargs [String] :custom_instructions Additional system prompt instructions
      def initialize(tools:, model:, max_tool_threads: nil, **)
        super(tools: tools, model: model, **)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end
    end
  end
end
