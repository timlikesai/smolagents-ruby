# frozen_string_literal: true

require "faraday"
require "nokogiri"

module Smolagents
  module DefaultTools
    # Web search tool using DuckDuckGo search engine.
    # Uses DuckDuckGo Lite HTML interface for searching.
    class DuckDuckGoSearchTool < Tool
      self.tool_name = "duckduckgo_search"
      self.description = "Performs a DuckDuckGo web search based on your query (like a Google search) then returns the top search results."
      self.inputs = {
        "query" => {
          "type" => "string",
          "description" => "The search query to perform."
        }
      }
      self.output_type = "string"

      # Initialize DuckDuckGo search tool.
      #
      # @param max_results [Integer] maximum number of results to return
      # @param rate_limit [Float, nil] queries per second limit (nil = no limit)
      def initialize(max_results: 10, rate_limit: 1.0)
        super()
        @max_results = max_results
        @rate_limit = rate_limit
        @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
        @last_request_time = 0.0
      end

      # Perform a DuckDuckGo search.
      #
      # @param query [String] search query
      # @return [String] formatted search results in markdown
      # @raise [StandardError] if no results found
      def forward(query:)
        enforce_rate_limit!

        results = search_duckduckgo(query)
        raise StandardError, "No results found! Try a less restrictive/shorter query." if results.empty?

        parse_results(results)
      end

      private

      # Search DuckDuckGo Lite interface.
      #
      # @param query [String] search query
      # @return [Array<Hash>] array of result hashes with :title, :link, :description
      def search_duckduckgo(query)
        conn = Faraday.new(url: "https://lite.duckduckgo.com") do |f|
          f.adapter Faraday.default_adapter
        end

        response = conn.get("/lite/") do |req|
          req.params["q"] = query
          req.headers["User-Agent"] = "Mozilla/5.0"
        end

        parse_duckduckgo_html(response.body)
      end

      # Parse DuckDuckGo Lite HTML response.
      #
      # @param html [String] HTML response
      # @return [Array<Hash>] parsed results
      def parse_duckduckgo_html(html)
        doc = Nokogiri::HTML(html)
        results = []

        # DuckDuckGo Lite uses table rows for results
        doc.css("tr").each do |row|
          result = {}

          # Extract title and link
          link_elem = row.at_css("a.result-link")
          if link_elem
            result[:title] = link_elem.text.strip
            # Extract the actual link from span.link-text
            link_text = link_elem.at_css("span.link-text")
            result[:link] = "https://#{link_text.text.strip}" if link_text
          end

          # Extract description
          snippet_elem = row.at_css("td.result-snippet")
          result[:description] = snippet_elem.text.strip if snippet_elem

          # Add to results if we have all required fields
          if result[:title] && result[:link] && result[:description]
            results << result
            break if results.size >= @max_results
          end
        end

        results
      end

      # Format results as markdown.
      #
      # @param results [Array<Hash>] search results
      # @return [String] markdown formatted results
      def parse_results(results)
        formatted = results.map do |result|
          "[#{result[:title]}](#{result[:link]})\n#{result[:description]}"
        end

        "## Search Results\n\n" + formatted.join("\n\n")
      end

      # Enforce rate limiting between requests.
      def enforce_rate_limit!
        return unless @rate_limit

        now = Time.now.to_f
        elapsed = now - @last_request_time

        sleep(@min_interval - elapsed) if elapsed < @min_interval

        @last_request_time = Time.now.to_f
      end
    end
  end
end
