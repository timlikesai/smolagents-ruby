module Smolagents
  module Tools
    # Search Wikipedia for encyclopedic information.
    #
    # Uses the Wikipedia API for structured access to encyclopedia content.
    # No API key required. Supports multiple languages via the language parameter.
    #
    # @example Basic usage
    #   tool = WikipediaSearchTool.new
    #   result = tool.call(query: "Ruby programming language")
    #   # => ToolResult with article titles, links, and snippets
    #
    # @example In an AgentBuilder
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { my_model }
    #     .tools(WikipediaSearchTool.new)
    #     .build
    #
    # @example Multi-language search
    #   tool = WikipediaSearchTool.new(language: "es")
    #   result = tool.call(query: "programacion")
    #   # => Results from Spanish Wikipedia
    #
    # @example In a pipeline with chaining
    #   Smolagents.pipeline
    #     .call(:wikipedia, query: :input)
    #     .pluck(:link)
    #     .take(3)
    #
    # @example With custom result limit
    #   tool = WikipediaSearchTool.new(language: "en", max_results: 5)
    #
    # @see DuckDuckGoSearchTool For general web search
    # @see SearchTool Base class for search tools
    class WikipediaSearchTool < SearchTool
      configure do |config|
        config.name "wikipedia"
        config.description "Search Wikipedia for encyclopedic information. Best for facts, history, and definitions."
        config.endpoint { |tool| "https://#{tool.language}.wikipedia.org/w/api.php" }
        config.parses :json
        config.query_param :srsearch
        config.query_input_description "Topic or subject to look up"
        config.additional_params action: "query", list: "search", format: "json", srprop: "snippet"
        config.results_path "query", "search"
        config.results_limit_param :srlimit
        config.field_mapping title: "title", description: "snippet"
        config.strip_html :description
        config.link_builder { |r| "https://#{language}.wikipedia.org/wiki/#{r["title"].tr(" ", "_")}" }
        config.optional_param :language, default: "en"
      end

      # @param language [String] Wikipedia language code (default: "en")
      # @param max_results [Integer] Maximum number of results (default: 10)
      def initialize(language: "en", max_results: 10, **)
        super
      end
    end
  end

  # Re-export WikipediaSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::WikipediaSearchTool
  WikipediaSearchTool = Tools::WikipediaSearchTool
end
