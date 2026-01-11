# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Search Wikipedia and return results with snippets.
    # Use visit_webpage with the result URL to fetch full article content.
    class WikipediaSearchTool < SearchTool
      # Wikipedia requests a descriptive user agent with contact info
      WIKIPEDIA_USER_AGENT = "Smolagents Ruby Agent (https://github.com/huggingface/smolagents)"

      self.tool_name = "wikipedia_search"
      self.description = "Searches Wikipedia and returns matching articles with snippets. " \
                         "Use visit_webpage with the article URL to read the full content."
      self.inputs = { query: { type: "string", description: "The topic to search on Wikipedia." } }
      self.output_type = "string"

      def initialize(language: "en", max_results: DEFAULT_MAX_RESULTS, **)
        super(max_results: max_results, **)
        @language = language
        @base_url = "https://#{language}.wikipedia.org/w/api.php"
        @user_agent = WIKIPEDIA_USER_AGENT
      end

      protected

      def perform_search(query, **)
        safe_api_call do
          response = http_get(@base_url, params: search_params(query))
          extract_results(parse_json_response(response))
        end
      end

      private

      def search_params(query)
        {
          action: "query",
          list: "search",
          srsearch: query,
          srlimit: @max_results,
          srprop: "snippet",
          format: "json"
        }
      end

      def extract_results(data)
        results = data.dig("query", "search") || []
        results.map do |result|
          {
            title: result["title"],
            link: article_url(result["title"]),
            description: clean_snippet(result["snippet"])
          }
        end
      end

      def article_url(title)
        encoded_title = title.gsub(" ", "_")
        "https://#{@language}.wikipedia.org/wiki/#{encoded_title}"
      end

      def clean_snippet(snippet)
        # Wikipedia returns HTML snippets with <span class="searchmatch"> tags
        snippet&.gsub(/<[^>]+>/, "")&.strip || ""
      end
    end
  end
end
