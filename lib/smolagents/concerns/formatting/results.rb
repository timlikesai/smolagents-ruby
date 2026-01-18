require_relative "results/extraction"
require_relative "results/messages"
require_relative "results/formatting"

module Smolagents
  module Concerns
    # Result formatting utilities for search and query tools.
    #
    # Provides methods for mapping raw API responses to standardized
    # result formats and rendering them as human-readable markdown.
    #
    # == Methods
    #
    # - Extraction: map_results(), extract_and_map(), extract_field()
    # - Messages: EMPTY_RESULTS_MESSAGE, build_results_output()
    # - Formatting: format_results(), format_results_with_metadata()
    #
    # @example Map API results to standard format
    #   class MySearchTool < Tool
    #     include Concerns::Results
    #
    #     def execute(query:)
    #       raw_results = fetch_api(query)
    #       results = map_results(raw_results, title: "name", link: "url")
    #       format_results(results)
    #     end
    #   end
    #
    # @example Format with metadata
    #   format_results(results, include_metadata: true, date: "published_at")
    module Results
      def self.included(base)
        base.include(Results::Extraction)
        base.include(Results::Messages)
        base.include(Results::Formatting)
      end
    end
  end
end
