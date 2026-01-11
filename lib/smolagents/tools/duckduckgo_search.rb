module Smolagents
  class DuckDuckGoSearchTool < Tool
    include Concerns::Http
    include Concerns::Html
    include Concerns::Results
    include Concerns::RateLimiter

    self.tool_name = "duckduckgo_search"
    self.description = "Searches the web using DuckDuckGo."
    self.inputs = { query: { type: "string", description: "The search query." } }
    self.output_type = "string"

    ENDPOINT = "https://lite.duckduckgo.com/lite/"

    rate_limit 1.0

    def initialize(max_results: 10, **)
      super()
      @max_results = max_results
    end

    def forward(query:)
      enforce_rate_limit!
      response = get(ENDPOINT, params: { q: query })
      results = parse_results(response.body)
      format_results(results)
    end

    private

    def parse_results(html)
      results = []
      parse_html(html).css("tr").each do |row|
        break if results.size >= @max_results

        link = row.at_css("a.result-link")
        snippet = row.at_css("td.result-snippet")
        link_text = link&.at_css("span.link-text")
        next unless link && snippet && link_text

        results << {
          title: link.text.strip,
          link: "https://#{link_text.text.strip}",
          description: snippet.text.strip
        }
      end
      results
    end
  end
end
