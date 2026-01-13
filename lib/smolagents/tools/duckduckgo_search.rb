module Smolagents
  module Tools
    # Web search tool using DuckDuckGo's lite interface.
    #
    # No API key required - uses the public lite.duckduckgo.com endpoint.
    # Includes rate limiting to avoid overwhelming the service.
    # Results are automatically formatted as ToolResult for chainability.
    #
    # @example Basic usage
    #   tool = DuckDuckGoSearchTool.new
    #   result = tool.call(query: "Ruby programming")
    #   # => ToolResult with title, link, description for each result
    #
    # @example In AgentBuilder
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { my_model }
    #     .tools(DuckDuckGoSearchTool.new)
    #     .build
    #
    # @example In a pipeline
    #   Smolagents.pipeline
    #     .call(:duckduckgo_search, query: :input)
    #     .select { |r| r[:description].length > 50 }
    #     .pluck(:link)
    #
    # @example With custom max_results
    #   tool = DuckDuckGoSearchTool.new(max_results: 5)
    #
    # Rate limiting:
    # - Default: 1 request per second
    # - Automatic enforcement via RateLimiter concern
    #
    # @see GoogleSearchTool For API-based Google search (requires key)
    # @see BraveSearchTool For Brave search API
    # @see SearchTool Base class for search tools
    class DuckDuckGoSearchTool < SearchTool
      configure do
        name "duckduckgo_search"
        description "Search the web using DuckDuckGo. Returns titles, URLs, and snippets. No API key required."
        endpoint "https://lite.duckduckgo.com/lite/"
        parses :html
        http_method :post
        rate_limit 1.0
        query_input_description "Search terms or question to look up"

        # HTML parsing configuration
        html_results "tr"
        html_field :title, selector: "a.result-link", extract: :text
        html_field :link, selector: "a.result-link", extract: :text, nested: "span.link-text", prefix: "https://"
        html_field :description, selector: "td.result-snippet", extract: :text
      end
    end
  end

  # Re-export DuckDuckGoSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::DuckDuckGoSearchTool
  DuckDuckGoSearchTool = Tools::DuckDuckGoSearchTool
end
