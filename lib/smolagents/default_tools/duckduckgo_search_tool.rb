# frozen_string_literal: true

require "faraday"
require "nokogiri"

module Smolagents
  module DefaultTools
    # Web search tool using DuckDuckGo Lite HTML interface.
    class DuckDuckGoSearchTool < Tool
      include Concerns::RateLimiter
      include Concerns::SearchResultFormatter

      self.tool_name = "duckduckgo_search"
      self.description = "Performs a DuckDuckGo web search based on your query then returns the top search results."
      self.inputs = { "query" => { "type" => "string", "description" => "The search query to perform." } }
      self.output_type = "string"

      def initialize(max_results: 10, rate_limit: 1.0)
        super()
        @max_results = max_results
        setup_rate_limiter(rate_limit)
      end

      def forward(query:)
        enforce_rate_limit!
        results = fetch_results(query)
        raise StandardError, "No results found! Try a less restrictive/shorter query." if results.empty?

        format_results(results)
      end

      private

      def fetch_results(query)
        response = Faraday.get("https://lite.duckduckgo.com/lite/", { q: query }, { "User-Agent" => "Mozilla/5.0" })
        parse_html(response.body)
      end

      def parse_html(html)
        Nokogiri::HTML(html).css("tr").each_with_object([]) do |row, results|
          break results if results.size >= @max_results

          link = row.at_css("a.result-link")
          snippet = row.at_css("td.result-snippet")
          next unless link && snippet

          link_text = link.at_css("span.link-text")
          next unless link_text

          results << { title: link.text.strip, link: "https://#{link_text.text.strip}", description: snippet.text.strip }
        end
      end

      def format_results(results) = format_search_results(results)
    end
  end
end
