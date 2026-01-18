module Smolagents
  module Tools
    # Web search tool using Google's Programmable Search Engine (PSE) API.
    #
    # Requires two credentials:
    # - GOOGLE_API_KEY: Your Google Cloud API key
    # - GOOGLE_CSE_ID: Your Programmable Search Engine ID (also called cx)
    #
    # Set up at:
    # - API Key: https://console.cloud.google.com/apis/credentials
    # - Search Engine: https://programmablesearchengine.google.com/
    #
    # Free tier: 100 queries/day. Additional queries: $5 per 1,000 (up to 10k/day).
    # Results are automatically formatted as ToolResult for chainability with
    # fields: :title, :link, :description.
    #
    # @example Creating the tool (requires GOOGLE_API_KEY and GOOGLE_CSE_ID env vars)
    #   # tool = Smolagents::GoogleSearchTool.new(max_results: 5)
    #   # tool.name  => "google_search"
    #
    # @see https://developers.google.com/custom-search/v1/overview Google PSE Documentation
    # @see DuckDuckGoSearchTool For searches without API key requirements
    # @see BraveSearchTool For alternative API-based search
    # @see SearchTool Base class for search tools
    # @see Tool Base class for all tools
    class GoogleSearchTool < SearchTool
      configure do |config|
        config.name "google_search"
        config.description <<~DESC.strip
          Search Google for current information using Programmable Search Engine.
          Requires GOOGLE_API_KEY and GOOGLE_CSE_ID environment variables.

          Use when: You need to find current web information or verify facts online.
          Do NOT use: If you already know the answer or need internal/local data.

          Returns: Array of results with title, link, and description fields.
        DESC
        config.endpoint "https://www.googleapis.com/customsearch/v1"
        config.parses :json
        config.requires_api_key "GOOGLE_API_KEY"
        config.api_key_param :key
        config.required_param :cse_id, env: "GOOGLE_CSE_ID", description: "Google Search Engine ID", as_param: :cx
        config.results_limit_param :num
        config.max_results_limit 10
        config.results_path "items"
        config.field_mapping title: "title", link: "link", description: "snippet"
      end
    end
  end

  # Re-export GoogleSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::GoogleSearchTool
  GoogleSearchTool = Tools::GoogleSearchTool
end
