# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module DefaultTools
    # Search Wikipedia and return the summary or full text of requested article.
    # Uses Wikipedia's MediaWiki API for searching and retrieving articles.
    class WikipediaSearchTool < Tool
      self.tool_name = "wikipedia_search"
      self.description = "Searches Wikipedia and returns a summary or full text of the given topic, along with the page URL."
      self.inputs = {
        "query" => {
          "type" => "string",
          "description" => "The topic to search on Wikipedia."
        }
      }
      self.output_type = "string"

      # Initialize Wikipedia search tool.
      #
      # @param user_agent [String] custom user-agent string (required by Wikipedia API policy)
      # @param language [String] language code for Wikipedia (e.g., 'en', 'fr', 'es')
      # @param content_type [String] 'summary' for intro or 'text' for full article
      def initialize(
        user_agent: "Smolagents (https://github.com/huggingface/smolagents)",
        language: "en",
        content_type: "text"
      )
        super()
        @user_agent = user_agent
        @language = language
        @content_type = content_type
        @base_url = "https://#{language}.wikipedia.org/w/api.php"
      end

      # Search Wikipedia for a topic.
      #
      # @param query [String] topic to search
      # @return [String] formatted Wikipedia content with URL
      def forward(query:)
        conn = Faraday.new(url: @base_url) do |f|
          f.headers["User-Agent"] = @user_agent
          f.adapter Faraday.default_adapter
        end

        # First, search for the page to get the actual title
        search_response = conn.get do |req|
          req.params["action"] = "query"
          req.params["list"] = "search"
          req.params["srsearch"] = query
          req.params["format"] = "json"
          req.params["srlimit"] = "1"
        end

        search_data = JSON.parse(search_response.body)
        search_results = search_data.dig("query", "search")

        if search_results.nil? || search_results.empty?
          return "No Wikipedia page found for '#{query}'. Try a different query."
        end

        title = search_results.first["title"]

        # Get the actual page content
        page_response = conn.get do |req|
          req.params["action"] = "query"
          req.params["prop"] = "extracts|info"
          req.params["titles"] = title
          req.params["format"] = "json"
          req.params["inprop"] = "url"
          req.params["explaintext"] = "1"  # Plain text, not HTML
          req.params["exsectionformat"] = "plain"

          # Get summary or full text
          req.params["exintro"] = "1" if @content_type == "summary"
        end

        page_data = JSON.parse(page_response.body)
        pages = page_data.dig("query", "pages")

        return "Error retrieving page content." if pages.nil?

        page = pages.values.first
        text = page["extract"]
        url = page["fullurl"]

        if text.nil? || text.empty?
          return "No content found for '#{title}'."
        end

        "✅ **Wikipedia Page:** #{title}\n\n**Content:** #{text}\n\n🔗 **Read more:** #{url}"
      rescue Faraday::Error => e
        "Error fetching Wikipedia content: #{e.message}"
      rescue JSON::ParserError => e
        "Error parsing Wikipedia response: #{e.message}"
      rescue StandardError => e
        "An unexpected error occurred: #{e.message}"
      end
    end
  end
end
