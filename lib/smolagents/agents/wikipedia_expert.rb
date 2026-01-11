module Smolagents
  module Agents
    class WikipediaExpert < ToolCalling
      INSTRUCTIONS = <<~INSTRUCTIONS
        You are a Wikipedia knowledge specialist. Your approach:
        1. Search for the most relevant Wikipedia article
        2. Extract key facts and dates accurately
        3. Note any ambiguities or multiple interpretations
        4. Cite the specific Wikipedia article in your answer
      INSTRUCTIONS

      def initialize(model:, **opts)
        tools = [
          Tools::WikipediaSearchTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, custom_instructions: INSTRUCTIONS, **opts)
      end
    end
  end
end
