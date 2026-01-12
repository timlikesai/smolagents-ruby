module Smolagents
  module Agents
    class WebScraper < Code
      INSTRUCTIONS = <<~TEXT.freeze
        You are a web content extraction specialist. Your approach:
        1. Search for relevant pages on the topic
        2. Visit pages and extract structured content
        3. Process and clean the extracted data with Ruby
        4. Return well-formatted, organized results
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
          Smolagents::RubyInterpreterTool.new,
          Smolagents::FinalAnswerTool.new
        ]
      end
    end
  end
end
