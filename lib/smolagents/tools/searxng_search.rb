module Smolagents
  # Search using a SearXNG instance (self-hosted metasearch engine).
  #
  # SearXNG aggregates results from multiple search engines while
  # respecting privacy. No API key required for self-hosted instances.
  #
  # @example Basic usage
  #   tool = SearxngSearchTool.new(instance_url: "https://searxng.example.com")
  #   result = tool.call(query: "Ruby programming")
  #
  # @example Using environment variable
  #   # Set SEARXNG_URL environment variable
  #   tool = SearxngSearchTool.new
  #
  # @example In a pipeline
  #   Smolagents.pipeline
  #     .call(:searxng_search, query: :input)
  #     .select { |r| r[:description].length > 50 }
  #     .pluck(:link)
  #
  # @example With categories
  #   tool = SearxngSearchTool.new(categories: "news")
  #   result = tool.call(query: "Ruby 4.0 release")
  #
  # @see SearchTool Base class with DSL
  # @see DuckDuckGoSearchTool Alternative no-API search
  class SearxngSearchTool < SearchTool
    configure do
      name "searxng_search"
      description "Search using SearXNG metasearch engine. Aggregates results from multiple sources. Requires SEARXNG_URL or instance_url parameter."
      parses :json
      results_path "results"
      field_mapping title: "title", link: "url", description: "content"

      # Instance URL is required - validates and creates accessor
      required_param :instance_url, env: "SEARXNG_URL", description: "SearXNG instance URL"

      # Categories with sensible default, included in query params
      optional_param :categories, default: "general", as_param: :categories

      # Dynamic endpoint using instance_url accessor
      endpoint { |tool| "#{tool.instance_url.chomp("/")}/search" }

      # Static params for all requests
      additional_params format: "json", pageno: 1
    end
  end
end
