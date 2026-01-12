module Smolagents
  module Agents
    # General-purpose interactive assistant agent.
    #
    # Uses ToolCallingAgent with user interaction, search, and browsing
    # capabilities. Can ask clarifying questions via UserInputTool.
    #
    # @example Basic usage
    #   assistant = Assistant.new(model: my_model)
    #   result = assistant.run("Help me understand Ruby's GIL")
    #
    # @example Interactive session
    #   # The assistant can ask follow-up questions when needed:
    #   result = assistant.run("What programming language should I learn?")
    #   # May prompt: "What's your background? What do you want to build?"
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For research-focused tasks
    class Assistant < ToolCalling
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
