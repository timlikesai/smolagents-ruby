require_relative "support/error_handling"
require_relative "support/result_templates"

module Smolagents
  module Tools
    # Shared helpers for tool implementations.
    #
    # The Support module provides reusable patterns that eliminate
    # repetitive code across tool implementations:
    #
    # - {ErrorHandling} - Convert errors to user-friendly strings
    # - {ResultTemplates} - Class-level DSL for common messages
    #
    # For result formatting, use Concerns::Results which provides:
    # - format_results() for field-mapped markdown formatting
    # - format_search_results() for custom item formatters
    #
    # @example Including support modules
    #   class MyTool < Tool
    #     include Concerns::Results
    #     include Support::ErrorHandling
    #     include Support::ResultTemplates
    #   end
    #
    # @see Concerns::Results For unified result formatting
    # @see ErrorHandling For HTTP error handling
    # @see ResultTemplates For message template DSL
    module Support
    end
  end
end
