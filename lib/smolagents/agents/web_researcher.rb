module Smolagents
  module Agents
    class WebResearcher < ToolCalling
      INSTRUCTIONS = <<~INSTRUCTIONS
        You are a web research specialist. Your approach:
        1. Start with broad searches to understand the topic
        2. Visit promising pages to gather detailed information
        3. Cross-reference facts across multiple sources
        4. Summarize findings with source citations
      INSTRUCTIONS

      def initialize(model:, **opts)
        tools = [
          Tools::DuckDuckGoSearchTool.new,
          Tools::VisitWebpageTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, custom_instructions: INSTRUCTIONS, **opts)
      end
    end
  end
end
