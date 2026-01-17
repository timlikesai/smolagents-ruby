require_relative "parsing/json"
require_relative "parsing/xml"
require_relative "parsing/html"
require_relative "parsing/critique"

module Smolagents
  module Concerns
    # Unified parsing concern for JSON, XML, and HTML.
    #
    # This concern provides a single include for tools that need
    # multiple parsing formats.
    #
    # @example Tool with multiple parsing needs
    #   class MyApiTool < Tool
    #     include Concerns::Parsing
    #
    #     def execute(url:)
    #       case url
    #       when /\.json$/ then parse_json(fetch(url))
    #       when /\.xml$/  then parse_xml(fetch(url))
    #       else                parse_html(fetch(url))
    #       end
    #     end
    #   end
    #
    # @see Json For JSON parsing
    # @see Xml For XML/RSS/Atom parsing
    # @see Html For HTML parsing
    module Parsing
      include Json
      include Xml
      include Html
    end
  end
end
