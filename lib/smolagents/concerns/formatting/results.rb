require_relative "results/extraction"
require_relative "results/messages"
require_relative "results/basic_formatting"
require_relative "results/metadata_formatting"

module Smolagents
  module Concerns
    # Result formatting utilities for search and query tools.
    #
    # Provides methods for mapping raw API responses to standardized
    # result formats and rendering them as human-readable markdown.
    #
    # == Composition
    #
    # Auto-includes these sub-concerns:
    #
    #   Results (this concern)
    #       |
    #       +-- Extraction: map_results(), extract_and_map(), extract_field()
    #       |
    #       +-- Messages: EMPTY_RESULTS_MESSAGE, RESULTS_NEXT_STEPS, build_results_output()
    #       |
    #       +-- BasicFormatting: format_results(), format_result_lines()
    #       |
    #       +-- MetadataFormatting: format_results_with_metadata()
    #
    # @example Map API results to standard format
    #   class MySearchTool < Tool
    #     include Concerns::Results
    #
    #     def execute(query:)
    #       raw_results = fetch_api(query)
    #       results = map_results(raw_results,
    #         title: "name",
    #         link: "url",
    #         description: "snippet"
    #       )
    #       format_results(results)
    #     end
    #   end
    #
    # @example Field mapping with Procs for transformation
    #   results = map_results(data,
    #     title: "name",
    #     link: ->(r) { "https://example.com/#{r["id"]}" },
    #     description: ->(r) { r["text"]&.truncate(200) }
    #   )
    #
    # @example Extract and map in one step
    #   results = extract_and_map(response,
    #     path: ["data", "items"],
    #     title: "title",
    #     link: "url",
    #     description: "summary"
    #   )
    #
    # @example Format with metadata
    #   format_results_with_metadata(results,
    #     title: "headline",
    #     link: "url",
    #     snippet: "excerpt",
    #     date: "published_at"
    #   )
    #
    # @see SearchTool Which includes this for result formatting
    # @see ToolResult For chainable result wrappers
    module Results
      def self.included(base)
        base.include(Results::Extraction)
        base.include(Results::Messages)
        base.include(Results::BasicFormatting)
        base.include(Results::MetadataFormatting)
      end
    end
  end
end
