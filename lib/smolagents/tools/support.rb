require_relative "support/formatted_result"
require_relative "support/error_handling"
require_relative "support/result_templates"

module Smolagents
  module Tools
    # Shared helpers for tool implementations.
    #
    # The Support module provides reusable patterns that eliminate
    # repetitive code across tool implementations:
    #
    # - {FormattedResult} - Format search results with counts, separators
    # - {ErrorHandling} - Convert errors to user-friendly strings
    # - {ResultTemplates} - Class-level DSL for common messages
    #
    # @example Including all support modules
    #   class MyTool < Tool
    #     include Support::FormattedResult
    #     include Support::ErrorHandling
    #     include Support::ResultTemplates
    #   end
    #
    # @see FormattedResult For search result formatting
    # @see ErrorHandling For HTTP error handling
    # @see ResultTemplates For message template DSL
    module Support
    end
  end
end
