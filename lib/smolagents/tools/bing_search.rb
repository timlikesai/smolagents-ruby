module Smolagents
  class BingSearchTool < Tool
    include Concerns::Http
    include Concerns::Xml
    include Concerns::Results

    self.tool_name = "bing_search"
    self.description = "Search the web using Bing RSS feed. Returns titles, URLs, and snippets. No API key required."
    self.inputs = { query: { type: "string", description: "Search terms or question to look up" } }
    self.output_type = "string"

    ENDPOINT = "https://www.bing.com/search".freeze

    def initialize(max_results: 10, **)
      super()
      @max_results = max_results
    end

    def execute(query:)
      response = get(ENDPOINT, params: { q: query, format: "rss" })
      results = parse_rss_items(response.body, limit: @max_results)
      format_results(results)
    end
  end
end
