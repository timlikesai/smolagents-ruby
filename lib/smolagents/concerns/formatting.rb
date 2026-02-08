require_relative "formatting/results"
require_relative "formatting/output"
require_relative "formatting/messages"
require_relative "formatting/structure"
require_relative "formatting/message_sanitization"

module Smolagents
  module Concerns
    # IMPORTANT: Unified formatting system for ALL output transformation.
    #
    # == When to Use This
    #
    # Use this module (or its sub-modules) whenever you need to:
    # - Format data for display to users or agents
    # - Describe data structures with access patterns
    # - Build LLM messages
    # - Map/transform API results
    #
    # == Sub-Modules
    #
    #   Results (search result mapping)
    #       map_results(data, **field_map) - Normalize API results
    #       extract_results(response, path:) - Extract from nested JSON
    #       truncate_results(results, max:) - Limit result count
    #
    #   ResultFormatting (output formatting)
    #       as_markdown, as_table, as_list - Format data for display
    #       truncate_str(text, width) - Truncate with ellipsis
    #
    #   MessageFormatting (LLM message building)
    #       format_system_message, format_user_message, etc.
    #
    #   StructureFormatting (data structure descriptions)
    #       describe(value, var:) - Show type, keys, and access patterns
    #       accessor(key) - Format key accessor ([:sym] or ["str"])
    #       sample(value) - Safe truncated inspect
    #
    # == Usage
    #
    # Include the full module for all formatting:
    #   include Concerns::Formatting
    #
    # Or use sub-modules directly:
    #   StructureFormatting.describe(data)
    #   StructureFormatting.accessor(:key)
    #
    # @example Describe data structure for code agent
    #   StructureFormatting.describe([{title: "Ruby 4.0", link: "..."}])
    #   # => "result = Array[1]
    #   #      Each element has keys: :title, :link
    #   #      Access first: result[0] or result.first
    #   #      ..."
    #
    # @example Format search results
    #   include Concerns::Formatting
    #   mapped = map_results(raw, title: "name", link: "url")
    #   format_results(mapped)
    #
    # @see StructureFormatting For describing data for code agents
    # @see Results For search result mapping
    # @see ResultFormatting For markdown/table/list output
    # @see MessageFormatting For LLM message building
    module Formatting
      include Results
      include ResultFormatting
      include MessageFormatting
    end
  end
end
