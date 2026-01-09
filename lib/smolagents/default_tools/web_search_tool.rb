# frozen_string_literal: true

require "faraday"
require "nokogiri"

module Smolagents
  module DefaultTools
    # Multi-engine web search tool.
    # Supports DuckDuckGo and Bing search engines.
    class WebSearchTool < Tool
      self.tool_name = "web_search"
      self.description = "Performs a web search for a query and returns the top search results formatted as markdown with titles, links, and descriptions."
      self.inputs = {
        "query" => {
          "type" => "string",
          "description" => "The search query to perform."
        }
      }
      self.output_type = "string"

      # Initialize web search tool.
      #
      # @param max_results [Integer] maximum number of results
      # @param engine [String] search engine to use ('duckduckgo' or 'bing')
      def initialize(max_results: 10, engine: "duckduckgo")
        super()
        @max_results = max_results
        @engine = engine
      end

      # Perform a web search.
      #
      # @param query [String] search query
      # @return [String] formatted search results
      def forward(query:)
        results = search(query)
        raise StandardError, "No results found! Try a less restrictive/shorter query." if results.empty?

        parse_results(results)
      end

      private

      # Perform search using configured engine.
      #
      # @param query [String] search query
      # @return [Array<Hash>] search results
      def search(query)
        case @engine
        when "duckduckgo"
          search_duckduckgo(query)
        when "bing"
          search_bing(query)
        else
          raise ArgumentError, "Unsupported engine: #{@engine}"
        end
      end

      # Search DuckDuckGo.
      #
      # @param query [String] search query
      # @return [Array<Hash>] results with :title, :link, :description
      def search_duckduckgo(query)
        conn = Faraday.new(url: "https://lite.duckduckgo.com")

        response = conn.get("/lite/") do |req|
          req.params["q"] = query
          req.headers["User-Agent"] = "Mozilla/5.0"
        end

        parse_duckduckgo_html(response.body)
      end

      # Search Bing RSS feed.
      #
      # @param query [String] search query
      # @return [Array<Hash>] results with :title, :link, :description
      def search_bing(query)
        conn = Faraday.new(url: "https://www.bing.com")

        response = conn.get("/search") do |req|
          req.params["q"] = query
          req.params["format"] = "rss"
        end

        parse_bing_xml(response.body)
      end

      # Parse DuckDuckGo HTML.
      #
      # @param html [String] HTML response
      # @return [Array<Hash>] parsed results
      def parse_duckduckgo_html(html)
        doc = Nokogiri::HTML(html)
        results = []

        doc.css("tr").each do |row|
          result = {}

          link_elem = row.at_css("a.result-link")
          if link_elem
            result[:title] = link_elem.text.strip
            link_text = link_elem.at_css("span.link-text")
            result[:link] = "https://#{link_text.text.strip}" if link_text
          end

          snippet_elem = row.at_css("td.result-snippet")
          result[:description] = snippet_elem.text.strip if snippet_elem

          if result[:title] && result[:link] && result[:description]
            results << result
            break if results.size >= @max_results
          end
        end

        results
      end

      # Parse Bing XML RSS feed.
      #
      # @param xml [String] XML response
      # @return [Array<Hash>] parsed results
      def parse_bing_xml(xml)
        doc = Nokogiri::XML(xml)
        doc.xpath("//item").take(@max_results).map do |item|
          {
            title: item.at_xpath("title")&.text,
            link: item.at_xpath("link")&.text,
            description: item.at_xpath("description")&.text
          }
        end
      end

      # Format results as markdown.
      #
      # @param results [Array<Hash>] search results
      # @return [String] markdown formatted string
      def parse_results(results)
        formatted = results.map do |result|
          "[#{result[:title]}](#{result[:link]})\n#{result[:description]}"
        end

        "## Search Results\n\n#{formatted.join("\n\n")}"
      end
    end
  end
end
