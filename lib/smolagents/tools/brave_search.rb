module Smolagents
  module Tools
    # Search the web using Brave Search API.
    #
    # Requires BRAVE_API_KEY environment variable or api_key parameter.
    # Includes rate limiting to respect API quotas.
    #
    # @example Basic usage
    #   tool = BraveSearchTool.new
    #   result = tool.call(query: "Ruby programming")
    #
    # @example With explicit API key
    #   tool = BraveSearchTool.new(api_key: "your-api-key")
    #
    # @example In AgentBuilder
    #   agent = Smolagents.agent(:tool_calling)
    #     .model { my_model }
    #     .tools(BraveSearchTool.new, :final_answer)
    #     .build
    #
    # @see SearchTool Base class with DSL
    # @see GoogleSearchTool Alternative API-based search
    class BraveSearchTool < SearchTool
      configure do |config|
        config.name "brave_search"
        config.description "Search the web using Brave Search API. Returns titles, URLs, and snippets. Requires BRAVE_API_KEY."
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
