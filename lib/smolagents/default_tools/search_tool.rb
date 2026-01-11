# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Abstract base class for search tools.
    # Provides common functionality for web search, API search, and content search tools.
    #
    # Subclasses should:
    # - Set tool_name, description, inputs, output_type
    # - Implement #perform_search(query, **options) returning an array of result hashes
    # - Optionally override #format_results(results) for custom formatting
    #
    # @example
    #   class MySearchTool < SearchTool
    #     self.tool_name = "my_search"
    #     self.description = "Searches my data source"
    #     self.inputs = { query: { type: "string", description: "Search query" } }
    #     self.output_type = "string"
    #
    #     protected
    #
    #     def perform_search(query, **)
    #       # Return array of { title:, link:, description: } hashes
    #     end
    #   end
    class SearchTool < Tool
      include Concerns::HttpClient
      include Concerns::SearchResultFormatter

      # Default maximum results to return
      DEFAULT_MAX_RESULTS = 10

      attr_reader :max_results

      def initialize(max_results: DEFAULT_MAX_RESULTS, **)
        super()
        @max_results = max_results
      end

      def forward(query:, **)
        results = perform_search(query, **)
        raise StandardError, "No results found for '#{query}'. Try a different or broader query." if results.nil? || results.empty?

        format_results(results)
      end

      protected

      # Subclasses must implement this method.
      # @param query [String] the search query
      # @return [Array<Hash>] array of result hashes with :title, :link, :description keys
      def perform_search(query, **)
        raise NotImplementedError, "#{self.class}#perform_search must be implemented"
      end

      # Format results for output. Override for custom formatting.
      # @param results [Array<Hash>] search results
      # @return [String] formatted results
      def format_results(results)
        format_search_results(results)
      end
    end
  end
end
