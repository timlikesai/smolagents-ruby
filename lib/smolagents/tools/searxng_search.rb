module Smolagents
  module Tools
    # Search using a SearXNG instance (self-hosted metasearch engine).
    #
    # SearXNG aggregates results from multiple search engines (Google, Bing, etc.)
    # while respecting user privacy. No API key required for self-hosted instances.
    # Results come from multiple sources, providing diverse perspectives.
    #
    # Perfect for privacy-focused deployments or when you want to aggregate
    # results from multiple search engines without relying on a single provider.
    #
    # @example Basic usage
    #   tool = SearxngSearchTool.new(instance_url: "https://searxng.example.com")
    #   result = tool.call(query: "Ruby programming")
    #   # => ToolResult with results from multiple engines
    #
    # @example Using environment variable
    #   # Set SEARXNG_URL environment variable first
    #   tool = SearxngSearchTool.new
    #   result = tool.call(query: "machine learning")
    #
    # @example In a pipeline with filtering
    #   Smolagents.pipeline
    #     .call(:searxng_search, query: "Python frameworks")
    #     .select { |r| r[:description].length > 50 }
    #     .pluck(:link)
    #     .take(5)
    #
    # @example With specific search categories
    #   tool = SearxngSearchTool.new(
    #     instance_url: "https://searxng.example.com",
    #     categories: "news"  # News category aggregation
    #   )
    #   result = tool.call(query: "Ruby 4.0 release")
    #
    # @example Full example with environment and max results
    #   # Set SEARXNG_URL="https://searxng.example.com" in environment
    #   tool = SearxngSearchTool.new(max_results: 10, categories: "general")
    #   results = tool.call(query: "Web scraping tools")
    #   results.each { |r| puts "#{r[:title]} - #{r[:link]}" }
    #
    # @see SearchTool Base class with DSL
    # @see DuckDuckGoSearchTool Alternative no-API search engine
    # @see Tool Base class for all tools
    class SearxngSearchTool < SearchTool
      configure do |config|
        config.name "searxng_search"
        config.description <<~DESC.strip
          Search using a self-hosted SearXNG metasearch engine instance.
          Aggregates results from Google, Bing, and other engines privately.

          Use when: You want diverse results from multiple search engines.
          Do NOT use: If you already know the answer or need internal data.

          Returns: Array of results with title, link, and description fields.
        DESC
        config.parses :json
        config.results_path "results"
        config.field_mapping title: "title", link: "url", description: "content"

        # Instance URL is required - validates and creates accessor
        config.required_param :instance_url, env: "SEARXNG_URL", description: "SearXNG instance URL"

        # Categories with sensible default, included in query params
        config.optional_param :categories, default: "general", as_param: :categories

        # Dynamic endpoint using instance_url accessor
        config.endpoint { |tool| "#{tool.instance_url.chomp("/")}/search" }

        # Static params for all requests
        config.additional_params format: "json", pageno: 1
      end
    end
  end

  # Re-export SearxngSearchTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::SearxngSearchTool
  SearxngSearchTool = Tools::SearxngSearchTool
end
