module Smolagents
  module Agents
    # Specialized agent for web content extraction.
    #
    # Uses CodeAgent with search, visit, and Ruby processing for
    # structured extraction from web pages.
    #
    # @example Basic usage
    #   scraper = WebScraper.new(model: my_model)
    #   result = scraper.run("Extract all article titles from Hacker News")
    #
    # @example In a pipeline context
    #   # WebScraper is ideal when you need:
    #   # - Multi-page extraction
    #   # - Data cleaning with Ruby
    #   # - Structured output from unstructured HTML
    #
    # @see Concerns::Specialized DSL for defining specialized agents
    # @see Researcher For research without code execution
    class WebScraper < Code
      include Concerns::Specialized

      instructions <<~TEXT
        You are a web content extraction specialist. Your approach:
        1. Search for relevant pages on the topic
        2. Visit pages and extract structured content
        3. Process and clean the extracted data with Ruby
        4. Return well-formatted, organized results
      TEXT

      default_tools do |_options|
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
