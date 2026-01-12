module Smolagents
  class BraveSearchTool < Tool
    include Concerns::Http
    include Concerns::Json
    include Concerns::Api
    include Concerns::ApiKey
    include Concerns::Results
    include Concerns::RateLimiter

    self.tool_name = "brave_search"
    self.description = "Search the web using Brave Search API. Returns titles, URLs, and snippets. Requires BRAVE_API_KEY."
    self.inputs = { query: { type: "string", description: "Search terms or question to look up" } }
    self.output_type = "string"

    ENDPOINT = "https://api.search.brave.com/res/v1/web/search".freeze

    rate_limit 1.0

    def initialize(api_key: nil, max_results: 10, **)
      super()
      @max_results = max_results
      @api_key = optional_api_key(api_key, env_var: "BRAVE_API_KEY")
    end

    def forward(query:)
      enforce_rate_limit!
      safe_api_call do
        response = get(ENDPOINT,
                       params: { q: query, count: @max_results },
                       headers: { "X-Subscription-Token" => @api_key })
        require_success!(response)
        data = parse_json(response.body)
        results = extract_and_map(data, path: %w[web results],
                                        title: "title", link: "url", description: "description")
        format_results(results)
      end
    end
  end
end
