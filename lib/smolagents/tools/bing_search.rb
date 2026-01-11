module Smolagents
  class BingSearchTool < Tool
    include Concerns::Http
    include Concerns::Xml
    include Concerns::Results

    self.tool_name = "bing_search"
    self.description = "Searches the web using Bing."
    self.inputs = { query: { type: "string", description: "The search query." } }
    self.output_type = "string"

    ENDPOINT = "https://www.bing.com/search"

    def initialize(max_results: 10, **)
      super()
      @max_results = max_results
    end

    def forward(query:)
      response = get(ENDPOINT, params: { q: query, format: "rss" })
      results = parse_rss_items(response.body, limit: @max_results)
      format_results(results)
    end
  end
end
