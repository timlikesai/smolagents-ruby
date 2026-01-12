module Smolagents
  class GoogleSearchTool < Tool
    include Concerns::Http
    include Concerns::Json
    include Concerns::Api
    include Concerns::ApiKey
    include Concerns::Results

    self.tool_name = "google_search"
    self.description = "Search Google for current information. Returns titles, URLs, and snippets. Requires SERPAPI_API_KEY or SERPER_API_KEY."
    self.inputs = {
      query: { type: "string", description: "Search terms or question to look up" },
      filter_year: { type: "integer", description: "Limit results to a specific year", nullable: true }
    }
    self.output_type = "string"

    PROVIDERS = {
      "serpapi" => { url: "https://serpapi.com/search.json", key_env: "SERPAPI_API_KEY", results_key: "organic_results", auth: :query },
      "serper" => { url: "https://google.serper.dev/search", key_env: "SERPER_API_KEY", results_key: "organic", auth: :header }
    }.freeze

    def initialize(provider: "serpapi", api_key: nil, max_results: 10, **)
      super()
      @max_results = max_results
      config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
      @base_url = config[:url]
      @results_key = config[:results_key]
      @auth_method = config[:auth]
    end

    def forward(query:, filter_year: nil)
      safe_api_call do
        response = get(@base_url, params: build_params(query, filter_year), headers: build_headers)
        require_success!(response)
        data = parse_json(response.body)
        results = extract_json(data, @results_key) || []
        return "No results found for '#{query}'#{" (year: #{filter_year})" if filter_year}." if results.empty?

        format_results_with_metadata(results)
      end
    end

    private

    def build_params(query, filter_year)
      params = { q: query }
      params.merge!(api_key: @api_key, engine: "google", google_domain: "google.com") if @auth_method == :query
      params[:tbs] = "cdr:1,cd_min:01/01/#{filter_year},cd_max:12/31/#{filter_year}" if filter_year
      params
    end

    def build_headers
      @auth_method == :header ? { "X-API-Key" => @api_key } : {}
    end
  end
end
