# frozen_string_literal: true

module Smolagents
  module Agents
    class Researcher < ToolCalling
      INSTRUCTIONS = <<~TEXT
        You are a research specialist. Your approach:
        1. Search for relevant information on the topic
        2. Gather detailed facts from promising sources
        3. Cross-reference information across sources
        4. Summarize findings with citations
      TEXT

      def initialize(model:, **)
        super(
          tools: default_tools,
          model: model,
          custom_instructions: INSTRUCTIONS,
          **
        )
      end

      private

      def default_tools
        [
          Smolagents::DuckDuckGoSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::WikipediaSearchTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
