module Smolagents
  module Tools
    # Tool for requesting interactive input from the user.
    #
    # UserInputTool enables agents to ask clarifying questions and wait for
    # user responses. This creates an interactive loop where the agent can
    # gather additional information needed to complete a task.
    #
    # The tool prints a question to stdout and reads from stdin, making it
    # suitable for terminal-based applications. For GUI or web applications,
    # you may need to subclass and override the execute method.
    #
    # @example Using with an agent
    #   agent = CodeAgent.new(
    #     tools: [UserInputTool.new],
    #     model: model
    #   )
    #   # Agent can now ask: ask_user(question: "What file should I process?")
    #
    # @example Direct tool usage
    #   tool = Smolagents::UserInputTool.new
    #   response = tool.call(question: "What is your name?")
    #   # User sees: "What is your name? => "
    #   # User types: "Alice"
    #   # => ToolResult with data: "Alice"
    #
    # @example Agent requesting clarification
    #   # Within agent code execution:
    #   #   filename = ask_user(question: "Which file should I analyze?")
    #   #   format = ask_user(question: "Output format? (json/csv/text)")
    #
    # @see Tool Base class for tool definitions
    # @see CodeAgent Agent that can use this tool in generated code
    class UserInputTool < Tool
      self.tool_name = "ask_user"
      self.description = <<~DESC.strip
        Ask the user a question and wait for their typed response.
        Useful for gathering information you cannot find or infer.

        Use when: You need clarification, preferences, or specific user input.
        Do NOT use: For questions you can answer yourself or find via search.

        Returns: The user's text response as a string.
      DESC
      self.inputs = { question: { type: "string", description: "Clear, specific question for the user" } }
      self.output_type = "string"

      # Asks the user a question and returns their response.
      #
      # Prints the question to stdout with a " => " prompt suffix,
      # then reads a single line from stdin. The newline is stripped
      # from the response.
      #
      # @param question [String] The question to display to the user
      # @return [String] The user's response with trailing newline removed
      #
      # @example
      #   execute(question: "Enter your API key")
      #   # Prints: "Enter your API key => "
      #   # Waits for input, returns the entered text
      #
      # @note This method blocks until the user provides input.
      #   For non-blocking input, consider implementing a custom tool.
      def execute(question:)
        print "#{question} => "
        $stdin.gets.chomp
      end
    end
  end

  # Re-export UserInputTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::UserInputTool
  UserInputTool = Tools::UserInputTool
end
