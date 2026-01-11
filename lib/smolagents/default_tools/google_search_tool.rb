# frozen_string_literal: true

require "json"

module Smolagents
  module DefaultTools
    # Google search tool using SerpAPI or Serper API.
    class GoogleSearchTool < SearchTool
      include Concerns::ApiKeyManagement

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

      def initialize(provider: "serpapi", api_key: nil, **)
        super(**)
        config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
        @base_url = config[:url]
        @results_key = config[:results_key]
        @auth_method = config[:auth]
      end

      # Override forward to provide custom empty-results handling with filter_year context
      def forward(query:, filter_year: nil)
        results = perform_search(query, filter_year: filter_year)
        return no_results_message(query, filter_year) if results.nil? || results.empty?

        format_results(results)
      end

      protected

      def perform_search(query, filter_year: nil)
        params = build_params(query, filter_year)
        headers = build_headers

        safe_api_call do
          response = http_get(@base_url, params: params, headers: headers)
          raise StandardError, "Search API error: #{response.status}" unless response.success?

          extract_results(JSON.parse(response.body))
        end
      end

      def format_results(results)
        format_search_results_with_metadata(results)
      end

      private

      def build_params(query, filter_year)
        params = { "q" => query }
        if @auth_method == :query
          # SerpAPI only supports query param auth (their API design)
          params["api_key"] = @api_key
          params.merge!("engine" => "google", "google_domain" => "google.com")
        end
        params["tbs"] = "cdr:1,cd_min:01/01/#{filter_year},cd_max:12/31/#{filter_year}" if filter_year
        params
      end

      def build_headers
        @auth_method == :header ? { "X-API-Key" => @api_key } : {}
      end

      def extract_results(data)
        data[@results_key] || []
      end

      def no_results_message(query, filter_year)
        msg = "No results found for '#{query}'"
        msg += " (year: #{filter_year})" if filter_year
        "#{msg}. Try a broader query."
      end
    end
  end
end
