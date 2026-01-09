# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module DefaultTools
    # Google search tool using SerpAPI or Serper API.
    # Requires API key from respective provider.
    class GoogleSearchTool < Tool
      self.tool_name = "google_search"
      self.description = "Performs a Google web search for your query then returns the top search results."
      self.inputs = {
        "query" => {
          "type" => "string",
          "description" => "The search query to perform."
        },
        "filter_year" => {
          "type" => "integer",
          "description" => "Optionally restrict results to a certain year",
          "nullable" => true
        }
      }
      self.output_type = "string"

      # Initialize Google search tool.
      #
      # @param provider [String] API provider ('serpapi' or 'serper')
      # @param api_key [String, nil] API key (defaults to environment variable)
      # @raise [ArgumentError] if API key is missing
      def initialize(provider: "serpapi", api_key: nil)
        super()
        @provider = provider

        if provider == "serpapi"
          @organic_key = "organic_results"
          api_key_env_name = "SERPAPI_API_KEY"
          @base_url = "https://serpapi.com/search.json"
        else
          @organic_key = "organic"
          api_key_env_name = "SERPER_API_KEY"
          @base_url = "https://google.serper.dev/search"
        end

        @api_key = api_key || ENV[api_key_env_name]

        unless @api_key
          raise ArgumentError, "Missing API key. Set '#{api_key_env_name}' environment variable."
        end
      end

      # Perform Google search.
      #
      # @param query [String] search query
      # @param filter_year [Integer, nil] optional year filter
      # @return [String] formatted search results
      # @raise [StandardError] if no results found
      def forward(query:, filter_year: nil)
        conn = Faraday.new(url: @base_url)

        params = build_params(query, filter_year)
        response = conn.get do |req|
          params.each { |k, v| req.params[k] = v }
        end

        unless response.success?
          raise StandardError, "Search API error: #{response.status}"
        end

        results = JSON.parse(response.body)
        format_results(results, query, filter_year)
      rescue Faraday::Error => e
        "Error performing Google search: #{e.message}"
      rescue JSON::ParserError => e
        "Error parsing search results: #{e.message}"
      end

      private

      # Build request parameters.
      #
      # @param query [String] search query
      # @param filter_year [Integer, nil] optional year filter
      # @return [Hash] parameters hash
      def build_params(query, filter_year)
        if @provider == "serpapi"
          params = {
            "q" => query,
            "api_key" => @api_key,
            "engine" => "google",
            "google_domain" => "google.com"
          }
        else
          params = {
            "q" => query,
            "api_key" => @api_key
          }
        end

        if filter_year
          params["tbs"] = "cdr:1,cd_min:01/01/#{filter_year},cd_max:12/31/#{filter_year}"
        end

        params
      end

      # Format search results as markdown.
      #
      # @param results [Hash] API response
      # @param query [String] original query
      # @param filter_year [Integer, nil] year filter
      # @return [String] formatted results
      def format_results(results, query, filter_year)
        unless results.key?(@organic_key)
          year_msg = filter_year ? " with filtering on year=#{filter_year}" : ""
          raise StandardError, "No results found for query: '#{query}'#{year_msg}. " \
                               "Use a less restrictive query#{filter_year ? ' or remove year filter' : ''}."
        end

        organic_results = results[@organic_key]

        if organic_results.empty?
          year_msg = filter_year ? " with filter year=#{filter_year}" : ""
          return "No results found for '#{query}'#{year_msg}. " \
                 "Try with a more general query#{filter_year ? ', or remove the year filter' : ''}."
        end

        web_snippets = organic_results.map.with_index do |page, idx|
          date_published = page["date"] ? "\nDate published: #{page['date']}" : ""
          source = page["source"] ? "\nSource: #{page['source']}" : ""
          snippet = page["snippet"] ? "\n#{page['snippet']}" : ""

          "#{idx}. [#{page['title']}](#{page['link']})#{date_published}#{source}#{snippet}"
        end

        "## Search Results\n" + web_snippets.join("\n\n")
      end
    end
  end
end
