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
    # Results are automatically formatted as ToolResult for chainability.
    #
    # @example Basic usage in an agent
    #   agent = Agents::Code.new(
    #     model: my_model,
    #     tools: [GoogleSearchTool.new]
    #   )
    #
    # @example With explicit credentials
    #   tool = GoogleSearchTool.new(
    #     api_key: ENV["GOOGLE_API_KEY"],
    #     cse_id: ENV["GOOGLE_CSE_ID"],
    #     max_results: 5
    #   )
    #
    # @example In a pipeline
    #   Smolagents.pipeline
    #     .call(:google_search, query: :input)
    #     .pluck(:link)
    #     .take(3)
    #
    # @see https://developers.google.com/custom-search/v1/overview Google PSE Documentation
    # @see DuckDuckGoSearchTool For searches without API key requirements
    # @see BraveSearchTool For alternative API-based search
    # @see SearchTool Base class for search tools
    class GoogleSearchTool < SearchTool
      configure do
        name "google_search"
        description "Search Google for current information. Returns titles, URLs, and snippets. Requires GOOGLE_API_KEY and GOOGLE_CSE_ID."
        endpoint "https://www.googleapis.com/customsearch/v1"
        parses :json
        requires_api_key "GOOGLE_API_KEY"
        api_key_param :key
        required_param :cse_id, env: "GOOGLE_CSE_ID", description: "Google Search Engine ID", as_param: :cx
        results_limit_param :num
        max_results_limit 10
        results_path "items"
        field_mapping title: "title", link: "link", description: "snippet"
      end
    end
  end

  # Re-export GoogleSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::GoogleSearchTool
  GoogleSearchTool = Tools::GoogleSearchTool
end
