module Smolagents
  module Tools
    # Web search tool using DuckDuckGo's lite interface.
    #
    # No API key required - uses the public lite.duckduckgo.com endpoint.
    # Includes rate limiting (1 request/second) to avoid overwhelming the service.
    # Results are automatically formatted as ToolResult for chainability with
    # fields: :title, :link, :description.
    #
    # **Best for:** Current events, recent news, real-time information, web content.
    # Use this when you need the most up-to-date information about something.
    # For established facts and encyclopedic content, prefer Wikipedia.
    #
    # @example Basic usage
    #   tool = DuckDuckGoSearchTool.new
    #   result = tool.call(query: "Ruby programming")
    #   # => ToolResult with [title, link, description] for each result
    #   result.first  # => { title: "...", link: "https://...", description: "..." }
    #
    # @example In AgentBuilder
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(DuckDuckGoSearchTool.new, :web, :final_answer)
    #     .build
    #   agent.run("What is the latest news about Ruby 4.0?")
    #
    # @example In a pipeline with filtering
    #   Smolagents.pipeline
    #     .call(:duckduckgo_search, query: "machine learning frameworks")
    #     .select { |r| r[:description].length > 50 }
    #     .pluck(:link)
    #     .take(3)
    #
    # @example With custom max_results
    #   tool = DuckDuckGoSearchTool.new(max_results: 5)
    #   result = tool.call(query: "web development")
    #
    # Rate limiting:
    # - Default: 1 request per second
    # - Automatic enforcement via RateLimiter concern
    # - Prevents rate-limiting errors from the DuckDuckGo service
    #
    # @see GoogleSearchTool For API-based Google search (requires key, higher quotas)
    # @see BraveSearchTool For Brave search API
    # @see WikipediaSearchTool For encyclopedic facts and established information
    # @see VisitWebpageTool Complementary tool to fetch full webpage content
    # @see SearchTool Base class for search tools
    # @see Tool Base class for all tools
    class DuckDuckGoSearchTool < SearchTool
      configure do |config|
        config.name "duckduckgo_search"
        config.description <<~DESC.strip
          Search the web using DuckDuckGo. Returns titles, URLs, and snippets.
          Best for: current events, recent news, real-time information, web content.
          No API key required. Use this for up-to-date information.
        DESC
        config.endpoint "https://lite.duckduckgo.com/lite/"
        config.parses :html
        config.http_method :post
        config.rate_limit 1.0
        config.query_input_description "Search terms or question to look up"
        config.browser_mode # DDG lite blocks bot User-Agents

        # HTML parsing configuration
        config.html_results "tr"
        config.html_field :title, selector: "a.result-link", extract: :text
        config.html_field :link, selector: "a.result-link", extract: :text, nested: "span.link-text", prefix: "https://"
        config.html_field :description, selector: "td.result-snippet", extract: :text
      end
    end
  end

  # Re-export DuckDuckGoSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::DuckDuckGoSearchTool
  DuckDuckGoSearchTool = Tools::DuckDuckGoSearchTool
end
