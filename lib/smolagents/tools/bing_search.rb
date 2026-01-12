module Smolagents
  # Search the web using Bing's RSS feed interface.
  #
  # No API key required - uses the public RSS endpoint.
  # Returns results as ToolResult for chainability.
  #
  # @example Basic usage
  #   tool = BingSearchTool.new
  #   result = tool.call(query: "Ruby programming")
  #   # => ToolResult with title, link, description for each result
  #
  # @example With result limit
  #   tool = BingSearchTool.new(max_results: 5)
  #   result = tool.call(query: "Ruby gems")
  #
  # @example In a pipeline
  #   Smolagents.pipeline
  #     .call(:bing_search, query: :input)
  #     .pluck(:link)
  #     .take(5)
  #
  # @example Accessing structured results
  #   result = tool.call(query: "machine learning")
  #   result.each do |item|
  #     puts "#{item[:title]}: #{item[:link]}"
  #   end
  #
  # @see SearchTool Base class with DSL
  # @see DuckDuckGoSearchTool Alternative no-API search
  class BingSearchTool < SearchTool
    configure do
      name "bing_search"
      description "Search the web using Bing RSS feed. Returns titles, URLs, and snippets. No API key required."
      endpoint "https://www.bing.com/search"
      parses :rss
      additional_params format: "rss"
    end
  end
end
