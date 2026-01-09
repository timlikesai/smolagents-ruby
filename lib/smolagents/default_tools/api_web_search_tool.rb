# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module DefaultTools
    # Generic API-based web search tool with rate limiting.
    # Defaults to Brave Search API but can be configured for any search API.
    class ApiWebSearchTool < Tool
      self.tool_name = "api_web_search"
      self.description = "Performs a web search for a query using an API and returns the top search results formatted as markdown with titles, URLs, and descriptions."
      self.inputs = {
        "query" => {
          "type" => "string",
          "description" => "The search query to perform."
        }
      }
      self.output_type = "string"

      # Initialize API web search tool.
      #
      # @param endpoint [String] API endpoint URL
      # @param api_key [String] API key for authentication
      # @param api_key_name [String] environment variable name for API key
      # @param headers [Hash, nil] custom headers for requests
      # @param params [Hash, nil] default parameters for requests
      # @param rate_limit [Float, nil] queries per second (nil = no limit)
      def initialize(
        endpoint: nil,
        api_key: nil,
        api_key_name: "BRAVE_API_KEY",
        headers: nil,
        params: nil,
        rate_limit: 1.0
      )
        super()
        @endpoint = endpoint || "https://api.search.brave.com/res/v1/web/search"
        @api_key_name = api_key_name
        @api_key = api_key || ENV[api_key_name]
        @headers = headers || {"X-Subscription-Token" => @api_key}
        @params = params || {"count" => 10}
        @rate_limit = rate_limit
        @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
        @last_request_time = 0.0
      end

      # Perform web search.
      #
      # @param query [String] search query
      # @return [String] formatted search results
      def forward(query:)
        enforce_rate_limit!

        conn = Faraday.new(url: @endpoint)
        params = @params.merge("q" => query)

        response = conn.get do |req|
          @headers.each { |k, v| req.headers[k] = v }
          params.each { |k, v| req.params[k] = v }
        end

        unless response.success?
          raise Faraday::Error, "API returned status #{response.status}"
        end

        data = JSON.parse(response.body)
        results = extract_results(data)
        format_markdown(results)
      rescue Faraday::Error => e
        "Error performing search: #{e.message}"
      rescue JSON::ParserError => e
        "Error parsing search results: #{e.message}"
      end

      private

      # Enforce rate limiting between requests.
      def enforce_rate_limit!
        return unless @rate_limit

        now = Time.now.to_f
        elapsed = now - @last_request_time

        sleep(@min_interval - elapsed) if elapsed < @min_interval

        @last_request_time = Time.now.to_f
      end

      # Extract results from API response.
      # Override this method for custom API response formats.
      #
      # @param data [Hash] API response
      # @return [Array<Hash>] extracted results
      def extract_results(data)
        results = []

        # Brave API format
        web_results = data.dig("web", "results") || []

        web_results.each do |result|
          results << {
            title: result["title"],
            url: result["url"],
            description: result["description"] || ""
          }
        end

        results
      end

      # Format results as markdown.
      #
      # @param results [Array<Hash>] search results
      # @return [String] formatted markdown
      def format_markdown(results)
        return "No results found." if results.empty?

        formatted = results.map.with_index do |result, idx|
          "#{idx + 1}. [#{result[:title]}](#{result[:url]})\n#{result[:description]}"
        end

        "## Search Results\n\n" + formatted.join("\n\n")
      end
    end
  end
end
