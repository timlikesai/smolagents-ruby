module Smolagents
  module Tools
    # Search Wikipedia for encyclopedic information.
    #
    # Uses the Wikipedia API for structured access to encyclopedia content.
    # No API key required. Supports multiple languages via the language parameter.
    # Results include article titles, links, and snippets with HTML stripped.
    #
    # Wikipedia is excellent for factual lookups, historical information,
    # and definitions. Agents can use this when they need authoritative,
    # well-sourced information about topics.
    #
    # @example Basic usage
    #   tool = WikipediaSearchTool.new
    #   result = tool.call(query: "Ruby programming language")
    #   # => ToolResult with article titles, links, and snippets
    #   result.first  # => { title: "Ruby (programming language)", link: "https://...", description: "..." }
    #
    # @example In an AgentBuilder
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(WikipediaSearchTool.new, :final_answer)
    #     .build
    #   agent.run("Tell me about machine learning")
    #
    # @example Multi-language search
    #   tool = WikipediaSearchTool.new(language: "es")
    #   result = tool.call(query: "programacion")
    #   # => Results from Spanish Wikipedia
    #
    # @example In a pipeline with chaining and filtering
    #   Smolagents.pipeline
    #     .call(:wikipedia, query: "climate change")
    #     .select { |r| r[:description].length > 100 }
    #     .pluck(:link)
    #     .take(3)
    #
    # @example With custom result limit and language
    #   tool = WikipediaSearchTool.new(language: "fr", max_results: 5)
    #   result = tool.call(query: "impressionnisme")
    #
    # @example Using with ToolResult transformations
    #   tool = WikipediaSearchTool.new
    #   results = tool.call(query: "quantum mechanics")
    #   summary = results.first(3)
    #     .map { |r| "#{r[:title]}: #{r[:description][0...100]}..." }
    #     .to_a.join("\n")
    #
    # @see DuckDuckGoSearchTool For general web search including news and blogs
    # @see SearchTool Base class for search tools
    # @see Tool Base class for all tools
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
