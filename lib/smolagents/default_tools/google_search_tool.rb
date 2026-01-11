# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module DefaultTools
    # Google search tool using SerpAPI or Serper API.
    class GoogleSearchTool < Tool
      include Concerns::HttpClient
      include Concerns::ApiKeyManagement
      include Concerns::SearchResultFormatter

      self.tool_name = "google_search"
      self.description = "Performs a Google web search and returns the top results."
      self.inputs = {
        query: { type: "string", description: "The search query to perform." },
        filter_year: { type: "integer", description: "Optionally restrict results to a certain year", nullable: true }
      }
      self.output_type = "string"

      PROVIDERS = {
        "serpapi" => { url: "https://serpapi.com/search.json", key_env: "SERPAPI_API_KEY", results_key: "organic_results", auth: :query },
        "serper" => { url: "https://google.serper.dev/search", key_env: "SERPER_API_KEY", results_key: "organic", auth: :header }
      }.freeze

      def initialize(provider: "serpapi", api_key: nil)
        super()
        config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
        @base_url = config[:url]
        @results_key = config[:results_key]
        @auth_method = config[:auth]
        @provider = provider
      end

      def forward(query:, filter_year: nil)
        params = { "q" => query }
        headers = {}

        # Use header auth where supported (more secure - keys not logged in URLs)
        if @auth_method == :header
          headers["X-API-Key"] = @api_key
        else
          # SerpAPI only supports query param auth (their API design)
          params["api_key"] = @api_key
          params.merge!("engine" => "google", "google_domain" => "google.com")
        end
        params["tbs"] = "cdr:1,cd_min:01/01/#{filter_year},cd_max:12/31/#{filter_year}" if filter_year

        safe_api_call do
          response = Faraday.get(@base_url, params, headers)
          raise StandardError, "Search API error: #{response.status}" unless response.success?

          format_results(JSON.parse(response.body), query, filter_year)
        end
      end

      private

      def format_results(data, query, filter_year)
        results = data[@results_key]
        raise StandardError, "No results found for '#{query}'" if results.nil?
        return no_results_message(query, filter_year) if results.empty?

        format_search_results_with_metadata(results)
      end

      def no_results_message(query, filter_year)
        msg = "No results found for '#{query}'"
        msg += " (year: #{filter_year})" if filter_year
        "#{msg}. Try a broader query."
      end
    end
  end
end
