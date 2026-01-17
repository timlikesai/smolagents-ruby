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
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern  | Depends On       | Depended By      | Auto-Includes |
    #   |----------|------------------|------------------|---------------|
    #   | Json     | -                | Parsing          | -             |
    #   | Xml      | Nokogiri (gem)   | Parsing          | -             |
    #   | Html     | Nokogiri (gem)   | Parsing, Browser | -             |
    #   | Critique | -                | -                | -             |
    #   | Parsing  | Json, Xml, Html  | -                | Json, Xml,    |
    #   |          |                  |                  | Html          |
    #
    # == Sub-concern Methods
    #
    #   Json
    #       +-- parse_json(string) - Parse JSON with error handling
    #       +-- safe_json_parse(string) - Parse JSON, return nil on error
    #       +-- extract_json_from_text(text) - Find JSON in mixed content
    #
    #   Xml
    #       +-- parse_xml(string) - Parse XML to Nokogiri document
    #       +-- parse_rss(string) - Parse RSS/Atom feeds
    #       +-- extract_xml_text(node) - Get clean text from XML node
    #
    #   Html
    #       +-- parse_html(string) - Parse HTML to Nokogiri document
    #       +-- extract_text(html) - Strip tags, normalize whitespace
    #       +-- extract_links(html) - Extract href attributes
    #       +-- extract_metadata(html) - Extract title, meta tags
    #
    #   Critique
    #       +-- parse_critique(response) - Parse model critique responses
    #       +-- extract_issues(critique) - Get list of issues
    #       +-- extract_suggestions(critique) - Get improvement suggestions
    #
    # == External Gem Dependencies
    #
    # - nokogiri (required by Xml, Html)
    #   Used for: XML/HTML parsing and DOM manipulation
    #
    # == No Instance Variables
    #
    # All parsing concerns are stateless and provide only methods.
    # They can be included in any class without side effects.
    #
    # @!endgroup
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
    # @see Critique For model critique response parsing
    module Parsing
      include Json
      include Xml
      include Html
    end
  end
end
