# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module DefaultTools
    # Generic API-based web search tool. Defaults to Brave Search API.
    class ApiWebSearchTool < Tool
      include Concerns::HttpClient
      include Concerns::RateLimiter
      include Concerns::ApiKeyManagement
      include Concerns::SearchResultFormatter

      self.tool_name = "api_web_search"
      self.description = "Performs a web search using an API and returns results as markdown."
      self.inputs = { "query" => { "type" => "string", "description" => "The search query to perform." } }
      self.output_type = "string"

      def initialize(endpoint: nil, api_key: nil, api_key_name: "BRAVE_API_KEY", headers: nil, params: nil, rate_limit: 1.0)
        super()
        @endpoint = endpoint || "https://api.search.brave.com/res/v1/web/search"
        @api_key = optional_api_key(api_key, env_var: api_key_name)
        @headers = headers || { "X-Subscription-Token" => @api_key }
        @params = params || { "count" => 10 }
        setup_rate_limiter(rate_limit)
      end

      def forward(query:)
        enforce_rate_limit!
        safe_api_call do
          response = Faraday.get(@endpoint, @params.merge("q" => query), @headers)
          raise Faraday::Error, "API returned status #{response.status}" unless response.success?

          format_results(extract_results(JSON.parse(response.body)))
        end
      end

      private

      def extract_results(data)
        (data.dig("web", "results") || []).map { |r| { title: r["title"], url: r["url"], description: r["description"] || "" } }
      end

      def format_results(results) = format_search_results(results, link: :url, indexed: true)
    end
  end
end
