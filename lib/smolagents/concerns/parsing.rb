require_relative "parsing/json"
require_relative "parsing/html"
require_relative "parsing/xml"
require_relative "parsing/critique"

module Smolagents
  module Concerns
    # Response parsing concerns for extracting structured data.
    #
    # Provides parsers for common response formats from LLMs and APIs.
    #
    # == Sub-Modules
    #
    #   Json
    #       Parse JSON from potentially malformed LLM output
    #
    #   Html
    #       Parse and extract content from HTML responses
    #
    #   Xml
    #       Parse and extract content from XML responses
    #
    #   Critique
    #       Parse critique/feedback responses from evaluation
    #
    # @see Json For JSON parsing with error recovery
    # @see Html For HTML content extraction
    # @see Xml For XML content extraction
    # @see Critique For evaluation feedback parsing
    module Parsing
    end
  end
end
