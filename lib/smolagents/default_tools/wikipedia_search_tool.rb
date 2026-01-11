# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Search Wikipedia and return the summary or full text of requested article.
    class WikipediaSearchTool < Tool
      include Concerns::HttpClient

      self.tool_name = "wikipedia_search"
      self.description = "Searches Wikipedia and returns a summary or full text of the given topic, along with the page URL."
      self.inputs = { query: { type: "string", description: "The topic to search on Wikipedia." } }
      self.output_type = "string"

      def initialize(user_agent: "Smolagents (https://github.com/huggingface/smolagents)", language: "en", content_type: "text")
        super()
        @user_agent = user_agent
        @content_type = content_type
        @base_url = "https://#{language}.wikipedia.org/w/api.php"
      end

      def forward(query:)
        title = search_title(query)
        return "No Wikipedia page found for '#{query}'. Try a different query." unless title

        page = fetch_page(title)
        return "Error retrieving page content." unless page

        text, url = page.values_at("extract", "fullurl")
        return "No content found for '#{title}'." if text.nil? || text.empty?

        "**Wikipedia Page:** #{title}\n\n**Content:** #{text}\n\n**Read more:** #{url}"
      rescue Faraday::Error, JSON::ParserError => e
        "Error: #{e.message}"
      end

      private

      def search_title(query)
        response = http_get(@base_url, params: { action: "query", list: "search", srsearch: query, format: "json", srlimit: 1 })
        parse_json_response(response).dig("query", "search", 0, "title")
      end

      def fetch_page(title)
        params = { action: "query", prop: "extracts|info", titles: title, format: "json", inprop: "url", explaintext: 1, exsectionformat: "plain" }
        params[:exintro] = 1 if @content_type == "summary"
        response = http_get(@base_url, params: params)
        parse_json_response(response).dig("query", "pages")&.values&.first
      end
    end
  end
end
