module Smolagents
  module Tools
    # Search the web using Brave Search API.
    #
    # Requires BRAVE_API_KEY environment variable or api_key parameter.
    # Includes rate limiting (1 request/second) to respect API quotas.
    # Results are automatically formatted as ToolResult for chainability with
    # fields: :title, :link, :description.
    #
    # Brave Search is a privacy-focused search engine API that provides
    # high-quality results. Perfect for applications requiring both privacy
    # and reliable search functionality.
    #
    # @example Creating the tool (requires BRAVE_API_KEY env var)
    #   # tool = Smolagents::BraveSearchTool.new
    #   # tool.name  => "brave_search"
    #
    # @see https://api.search.brave.com/res/v1/web/search Brave Search API Documentation
    # @see SearchTool Base class with DSL
    # @see GoogleSearchTool Alternative API-based search
    # @see DuckDuckGoSearchTool For no-API search alternative
    # @see Tool Base class for all tools
    class BraveSearchTool < SearchTool
      configure do |config|
        config.name "brave_search"
        config.description <<~DESC.strip
          Search the web using Brave Search API with privacy-focused results.
          Requires BRAVE_API_KEY environment variable for authentication.

          Use when: You need current web information with privacy guarantees.
          Do NOT use: If you already know the answer or need internal data.

          Returns: Array of results with title, link, and description fields.
        DESC
        config.endpoint "https://api.search.brave.com/res/v1/web/search"
        config.parses :json
        config.requires_api_key "BRAVE_API_KEY"
        config.rate_limit 1.0
        config.auth_header "X-Subscription-Token"
        config.results_path "web", "results"
        config.field_mapping title: "title", link: "url", description: "description"
      end
    end
  end

  # Re-export BraveSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::BraveSearchTool
  BraveSearchTool = Tools::BraveSearchTool
end
