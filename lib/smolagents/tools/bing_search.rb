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
    # @example Creating and using the tool
    #   tool = Smolagents::BingSearchTool.new(max_results: 5)
    #   tool.name
    #   # => "bing_search"
    #
    # @see SearchTool Base class with DSL
    # @see DuckDuckGoSearchTool Alternative no-API search
    # @see GoogleSearchTool For API-based search with key
    # @see Tool Base class for all tools
    class BingSearchTool < SearchTool
      configure do |config|
        config.name "bing_search"
        config.description <<~DESC.strip
          Search the web using Bing's RSS feed interface - no API key needed.
          Uses Bing's public search index for broad web coverage.

          Use when: You need web search without API key requirements.
          Do NOT use: If you already know the answer or need internal data.

          Returns: Array of results with title, link, and description fields.
        DESC
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
