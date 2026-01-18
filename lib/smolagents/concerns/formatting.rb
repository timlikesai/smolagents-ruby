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
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern           | Depends On | Depended By | Auto-Includes |
    #   |-------------------|------------|-------------|---------------|
    #   | Results           | -          | Formatting  | -             |
    #   | ResultFormatting  | -          | Formatting  | -             |
    #   | MessageFormatting | -          | Formatting  | -             |
    #   | Formatting        | Results,   | -           | Results,      |
    #   |                   | Result-,   |             | Result-,      |
    #   |                   | Message-   |             | Message-      |
    #
    # == Sub-concern Methods
    #
    #   Results (search result mapping)
    #       +-- map_results(data, **field_map) - Normalize API results
    #       +-- extract_results(response, path:) - Extract from nested JSON
    #       +-- truncate_results(results, max:) - Limit result count
    #
    #   ResultFormatting (output formatting)
    #       +-- format_results(results) - Convert to readable string
    #       +-- format_list(items) - Format as numbered list
    #       +-- format_table(rows, headers:) - Format as ASCII table
    #       +-- truncate_output(text, max_chars:) - Limit output length
    #
    #   MessageFormatting (LLM message building)
    #       +-- format_system_message(content) - Build system message
    #       +-- format_user_message(content) - Build user message
    #       +-- format_assistant_message(content) - Build assistant message
    #       +-- format_tool_message(name:, content:) - Build tool result
    #
    # == No Instance Variables
    #
    # All formatting concerns are stateless and provide only methods.
    # They can be included in any class without side effects.
    #
    # == No External Dependencies
    #
    # All formatting concerns use only Ruby stdlib.
    #
    # @!endgroup
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
