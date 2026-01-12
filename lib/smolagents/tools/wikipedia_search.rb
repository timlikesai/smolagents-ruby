module Smolagents
  class WikipediaSearchTool < Tool
    include Concerns::Http
    include Concerns::Json
    include Concerns::Html
    include Concerns::Results

    USER_AGENT = "Smolagents Ruby Agent (https://github.com/timlikesai/smolagents-ruby)".freeze

    self.tool_name = "wikipedia"
    self.description = "Search Wikipedia for encyclopedic information. Best for facts, history, and definitions."
    self.inputs = { query: { type: "string", description: "Topic or subject to look up" } }
    self.output_type = "string"

    def initialize(language: "en", max_results: 10, **)
      super()
      @max_results = max_results
      @language = language
      @base_url = "https://#{language}.wikipedia.org/w/api.php"
      @user_agent = USER_AGENT
    end

    def execute(query:)
      safe_api_call do
        response = get(@base_url, params: search_params(query))
        data = parse_json(response.body)
        results = map_results(extract_json(data, "query", "search") || [],
                              title: "title",
                              link: ->(r) { article_url(r["title"]) },
                              description: ->(r) { strip_html_tags(r["snippet"]) })
        format_results(results)
      end
    end

    private

    def search_params(query)
      { action: "query", list: "search", srsearch: query, srlimit: @max_results, srprop: "snippet", format: "json" }
    end

    def article_url(title) = "https://#{@language}.wikipedia.org/wiki/#{title.tr(" ", "_")}"
  end
end
