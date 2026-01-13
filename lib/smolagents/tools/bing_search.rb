module Smolagents
  module Tools
    # Search the web using Bing's RSS feed interface.
    #
    # No API key required - uses the public RSS endpoint via the format=rss parameter.
    # Returns results as ToolResult for chainability with fields: :title, :link,
    # :description.
    #
    # Bing provides a good alternative to other search engines with no API
    # key requirement. Results come from Bing's search index.
    #
    # @example Basic usage
    #   tool = BingSearchTool.new
    #   result = tool.call(query: "Ruby programming")
    #   # => ToolResult with title, link, description for each result
    #   result.first  # => { title: "...", link: "https://...", description: "..." }
    #
    # @example With result limit
    #   tool = BingSearchTool.new(max_results: 5)
    #   result = tool.call(query: "Ruby gems")
    #
    # @example In a pipeline with filtering
    #   Smolagents.pipeline
    #     .call(:bing_search, query: "web frameworks")
    #     .select { |r| r[:description].length > 50 }
    #     .pluck(:link)
    #     .take(5)
    #
    # @example Accessing structured results
    #   result = tool.call(query: "machine learning")
    #   result.each do |item|
    #     puts "#{item[:title]}: #{item[:link]}"
    #   end
    #
    # @example Using with ToolResult transformations
    #   tool = BingSearchTool.new(max_results: 10)
    #   results = tool.call(query: "Python libraries")
    #   top_3 = results.take(3).map { |r| r[:title] }
    #
    # @see SearchTool Base class with DSL
    # @see DuckDuckGoSearchTool Alternative no-API search
    # @see GoogleSearchTool For API-based search with key
    # @see Tool Base class for all tools
    class BingSearchTool < SearchTool
      configure do |config|
        config.name "bing_search"
        config.description "Search the web using Bing RSS feed. Returns titles, URLs, and snippets. No API key required."
        config.endpoint "https://www.bing.com/search"
        config.parses :rss
        config.additional_params format: "rss"
      end
    end
  end

  # Re-export BingSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::BingSearchTool
  BingSearchTool = Tools::BingSearchTool
end
