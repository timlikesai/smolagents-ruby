require_relative "formatting/results"
require_relative "formatting/output"
require_relative "formatting/messages"

module Smolagents
  module Concerns
    # Unified formatting concern for output transformation.
    #
    # Combines search result mapping, generic output formatting, and
    # LLM message formatting into a single composable concern.
    #
    # @example Tool with full formatting support
    #   class MySearchTool < Tool
    #     include Concerns::Formatting
    #
    #     def execute(query:)
    #       raw = fetch_results(query)
    #       mapped = map_results(raw, title: "name", link: "url")
    #       format_results(mapped)
    #     end
    #   end
    #
    # @see Results For search result mapping
    # @see ResultFormatting For generic output formatting
    # @see MessageFormatting For LLM message formatting
    module Formatting
      include Results
      include ResultFormatting
      include MessageFormatting
    end
  end
end
