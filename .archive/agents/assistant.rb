module Smolagents
  module Agents
    # General-purpose interactive assistant agent.
    #
    # Uses ToolAgent with user interaction, web search, and browsing
    # capabilities. Can ask clarifying questions via UserInputTool for better
    # understanding user needs before responding.
    #
    # The Assistant agent is optimized for:
    # - Answering general knowledge questions
    # - Having interactive conversations with clarifying questions
    # - Searching for current information when needed
    # - Browsing websites to fetch detailed information
    # - Providing actionable advice and recommendations
    # - Learning and adapting to user preferences
    #
    # Built-in tools:
    # - UserInputTool: Ask the user clarifying questions interactively
    # - DuckDuckGoSearchTool: Search for information across the web
    # - VisitWebpageTool: Fetch and analyze specific website content
    # - FinalAnswerTool: Submit formatted final response
    #
    # Unlike Researcher (for systematic information gathering), Assistant
    # is designed for natural conversation with immediate interactivity.
    #
    # @example Simple question answering
    #   assistant = Assistant.new(model: OpenAIModel.lm_studio("gemma-3n-e4b"))
    #   result = assistant.run("Explain Ruby's garbage collection")
    #   puts result.output
    #
    # @example Interactive session with clarifying questions
    #   # When the question is ambiguous, Assistant asks:
    #   result = assistant.run("What programming language should I learn?")
    #   # Assistant may ask: "What's your background? What do you want to build?"
    #   # User responds, assistant provides tailored recommendation
    #
    # @example Question with web search
    #   result = assistant.run(
    #     "What's the latest news about Ruby releases and what features are new?"
    #   )
    #
    # @example Technology comparison
    #   result = assistant.run(
    #     "Compare Ruby on Rails vs Django for web development. " \
    #     "I'm building an e-commerce site."
    #   )
    #
    # @example Problem solving
    #   result = assistant.run(
    #     "I'm getting a 'SyntaxError' in my Ruby code. " \
    #     "Can you help me understand what went wrong?"
    #   )
    #
    # @option kwargs [Integer] :max_steps Steps before giving up (default: 10)
    # @option kwargs [String] :custom_instructions Additional guidance for assistant behavior
    #
    # @raise [ArgumentError] If model doesn't support tool calling
    #
    # @see Tool Base agent type (JSON tool calling)
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For systematic research without interactive questions
    # @see UserInputTool For asking users questions
    # @see DuckDuckGoSearchTool For web search capability
    class Assistant < Tool
      include Concerns::Specialized

      instructions <<~TEXT
        You are a helpful interactive assistant. Your approach:
        1. Analyze the user's request carefully
        2. Ask clarifying questions when the request is ambiguous
        3. Use available tools to gather information or perform tasks
        4. Provide clear, actionable responses
      TEXT

      default_tools do |_options|
        [
          Smolagents::UserInputTool.new,
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
