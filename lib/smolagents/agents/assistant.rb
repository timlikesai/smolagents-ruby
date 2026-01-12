module Smolagents
  module Agents
    class Assistant < ToolCalling
      INSTRUCTIONS = <<~TEXT
        You are a helpful interactive assistant. Your approach:
        1. Analyze the user's request carefully
        2. Ask clarifying questions when the request is ambiguous
        3. Use available tools to gather information or perform tasks
        4. Provide clear, actionable responses
      TEXT

      def initialize(model:, **opts)
        super(
          tools: default_tools,
          model: model,
          custom_instructions: INSTRUCTIONS,
          **opts
        )
      end

      private

      def default_tools
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
