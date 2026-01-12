module Smolagents
  module Agents
    class FactChecker < ToolCalling
      INSTRUCTIONS = <<~TEXT.freeze
        You are a fact-checking specialist. Your approach:
        1. Identify the specific claims to verify
        2. Search multiple sources for corroborating evidence
        3. Cross-reference information across different sources
        4. Rate confidence level and cite sources for each finding
      TEXT

      def initialize(model:, search_provider: :duckduckgo, **)
        @search_provider = search_provider
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
          search_tool,
          Smolagents::WikipediaSearchTool.new,
          Smolagents::VisitWebpageTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end

      def search_tool
        case @search_provider
        when :brave then Smolagents::BraveSearchTool.new
        when :google then Smolagents::GoogleSearchTool.new
        when :bing then Smolagents::BingSearchTool.new
        else Smolagents::DuckDuckGoSearchTool.new
        end
      end
    end
  end
end
