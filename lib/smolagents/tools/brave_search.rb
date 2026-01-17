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
    # @example Basic usage (using environment variable)
    #   # Set BRAVE_API_KEY environment variable
    #   tool = BraveSearchTool.new
    #   result = tool.call(query: "Ruby programming")
    #   # => ToolResult with title, link, description for each result
    #
    # @example With explicit API key
    #   tool = BraveSearchTool.new(api_key: "your-brave-api-key")
    #   result = tool.call(query: "machine learning")
    #
    # @example In AgentBuilder
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(BraveSearchTool.new, :web, :final_answer)
    #     .build
    #   agent.run("Find information about Brave Search")
    #
    # @example In a pipeline with filtering
    #   Smolagents.pipeline
    #     .call(:brave_search, query: "web development")
    #     .select { |r| r[:description].length > 50 }
    #     .pluck(:link)
    #     .take(3)
    #
    # @example Using with ToolResult transformations
    #   tool = BraveSearchTool.new(max_results: 10)
    #   results = tool.call(query: "Ruby frameworks")
    #   summaries = results.take(5)
    #     .map { |r| "#{r[:title]} - #{r[:link]}" }
    #     .to_a.join("\n")
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
