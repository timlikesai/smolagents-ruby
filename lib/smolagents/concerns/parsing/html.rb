require "nokogiri"

module Smolagents
  module Concerns
    # HTML parsing utilities for tools that scrape web content.
    #
    # Provides methods for parsing HTML documents, selecting elements with CSS,
    # and extracting text content. Built on Nokogiri for robust parsing.
    #
    # @example Parse and select elements
    #   class MyScraper < Tool
    #     include Concerns::Html
    #
    #     def execute(url:)
    #       html = fetch_page(url)
    #       titles = css_select(html, "h1.title") { |el| text_content(el) }
    #       titles.join(", ")
    #     end
    #   end
    #
    # @example Extract links with attributes
    #   links = css_select(doc, "a.external", limit: 10) do |link|
    #     { text: text_content(link), href: attr_value(link, "href") }
    #   end
    #
    # @example Clean HTML from text
    #   clean = strip_html_tags("<p>Hello <b>world</b></p>")
    #   # => "Hello world"
    #
    # @see Xml For XML/RSS/Atom parsing
    # @see SearchTool Which includes this for HTML search results
    module Html
      # Parse HTML content into a Nokogiri document.
      # @param content [String] Raw HTML string
      # @return [Nokogiri::HTML::Document] Parsed document for querying
      def parse_html(content)
        Nokogiri::HTML(content)
      end

      # Select elements using CSS selectors with optional transformation.
      # @param doc_or_html [Nokogiri::HTML::Document, String] Document or raw HTML
      # @param selector [String] CSS selector (e.g., "div.content", "a[href]")
      # @param limit [Integer, nil] Maximum elements to return
      # @yield [element] Optional block to transform each element
      # @return [Array] Selected elements or transformed values
      def css_select(doc_or_html, selector, limit: nil, &)
        doc = doc_or_html.is_a?(String) ? parse_html(doc_or_html) : doc_or_html
        elements = doc.css(selector)
        elements = elements.take(limit) if limit
        block_given? ? elements.filter_map(&) : elements
      end

      # Remove all HTML tags from text, leaving plain content.
      # @param text [String, nil] Text potentially containing HTML
      # @return [String] Clean text with tags removed
      def strip_html_tags(text)
        text&.gsub(/<[^>]+>/, "")&.strip || ""
      end

      # Extract trimmed text content from an element.
      # @param element [Nokogiri::XML::Element, nil] HTML element
      # @return [String, nil] Text content or nil if element is nil
      def text_content(element)
        element&.text&.strip
      end

      # Get an attribute value from an element.
      # @param element [Nokogiri::XML::Element, nil] HTML element
      # @param attr [String] Attribute name (e.g., "href", "src", "class")
      # @return [String, nil] Attribute value or nil
      def attr_value(element, attr)
        element&.[](attr)
      end
    end
  end
end
