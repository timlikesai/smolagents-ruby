# frozen_string_literal: true

require "nokogiri"

module Smolagents
  module DefaultTools
    # Multi-engine web search tool supporting DuckDuckGo and Bing.
    class WebSearchTool < Tool
      include Concerns::HttpClient
      include Concerns::SearchResultFormatter

      self.tool_name = "web_search"
      self.description = "Performs a web search for a query and returns the top search results formatted as markdown."
      self.inputs = { "query" => { "type" => "string", "description" => "The search query to perform." } }
      self.output_type = "string"

      ENGINES = {
        "duckduckgo" => { url: "https://lite.duckduckgo.com", path: "/lite/", parser: :parse_duckduckgo },
        "bing" => { url: "https://www.bing.com", path: "/search", parser: :parse_bing, params: { "format" => "rss" } }
      }.freeze

      def initialize(max_results: 10, engine: "duckduckgo")
        super()
        @max_results = max_results
        @engine = ENGINES.fetch(engine) { raise ArgumentError, "Unsupported engine: #{engine}" }
        @user_agent = "Mozilla/5.0"
      end

      def forward(query:)
        response = http_get(@engine[:url] + @engine[:path], params: { "q" => query }.merge(@engine[:params] || {}))
        results = send(@engine[:parser], response.body)
        raise StandardError, "No results found! Try a less restrictive/shorter query." if results.empty?

        format_results(results)
      end

      private

      def parse_duckduckgo(html)
        Nokogiri::HTML(html).css("tr").each_with_object([]) do |row, results|
          break results if results.size >= @max_results
          link = row.at_css("a.result-link")
          snippet = row.at_css("td.result-snippet")
          link_text = link&.at_css("span.link-text")
          next unless link && snippet && link_text
          results << { title: link.text.strip, link: "https://#{link_text.text.strip}", description: snippet.text.strip }
        end
      end

      def parse_bing(xml)
        Nokogiri::XML(xml).xpath("//item").take(@max_results).map do |item|
          { title: item.at_xpath("title")&.text, link: item.at_xpath("link")&.text, description: item.at_xpath("description")&.text }
        end
      end

      def format_results(results) = format_search_results(results)
    end
  end
end
