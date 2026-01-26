require "nokogiri"

module Smolagents
  module Concerns
    # XML/RSS/Atom parsing utilities for tools that consume feeds.
    #
    # Provides methods for parsing XML documents, selecting elements with XPath,
    # and extracting content from RSS and Atom feeds. Built on Nokogiri.
    #
    # @example Parse XML and select elements
    #   class MyFeedReader < Tool
    #     include Concerns::Xml
    #
    #     def execute(feed_url:)
    #       xml = fetch_feed(feed_url)
    #       items = parse_rss_items(xml, limit: 5)
    #       format_results(items)
    #     end
    #   end
    #
    # @example XPath selection with transformation
    #   products = xpath_select(doc, "//product[@active='true']", limit: 10) do |p|
    #     { name: xpath_text(p, "name"), price: xpath_text(p, "price") }
    #   end
    #
    # @example Parse Atom feed
    #   entries = parse_atom_entries(xml, limit: 5)
    #   # => [{ title: "...", link: "...", description: "..." }, ...]
    #
    # @see Html For HTML parsing with CSS selectors
    # @see BingSearchTool Which uses RSS parsing
    module Xml
      # Parse XML content into a Nokogiri document.
      # @param content [String] Raw XML string
      # @return [Nokogiri::XML::Document] Parsed document for querying
      def parse_xml(content)
        Nokogiri::XML(content)
      end

      # Select elements using XPath with optional transformation.
      # @param doc_or_xml [Nokogiri::XML::Document, String] Document or raw XML
      # @param path [String] XPath expression (e.g., "//item", "//entry[@type='post']")
      # @param limit [Integer, nil] Maximum elements to return
      # @yield [element] Optional block to transform each element
      # @return [Array] Selected elements or transformed values
      def xpath_select(doc_or_xml, path, limit: nil, &)
        doc = doc_or_xml.is_a?(String) ? parse_xml(doc_or_xml) : doc_or_xml
        elements = doc.xpath(path)
        elements = elements.take(limit) if limit
        block_given? ? elements.filter_map(&) : elements
      end

      # Extract trimmed text from an XPath within an element.
      # @param element [Nokogiri::XML::Element] Parent element
      # @param path [String] XPath to child element (e.g., "title", "link")
      # @return [String, nil] Text content or nil if not found
      def xpath_text(element, path)
        element.at_xpath(path)&.text&.strip
      end

      # Parse RSS feed items into standardized result hashes.
      # @param xml [String, Nokogiri::XML::Document] RSS XML content
      # @param limit [Integer, nil] Maximum items to return
      # @return [Array<Hash>] Items with :title, :link, :description keys
      def parse_rss_items(xml, limit: nil)
        xpath_select(xml, "//item", limit:) do |item|
          {
            title: xpath_text(item, "title"),
            link: xpath_text(item, "link"),
            description: xpath_text(item, "description")
          }
        end
      end

      # Parse Atom feed entries into standardized result hashes.
      # @param xml [String, Nokogiri::XML::Document] Atom XML content
      # @param limit [Integer, nil] Maximum entries to return
      # @return [Array<Hash>] Entries with :title, :link, :description keys
      def parse_atom_entries(xml, limit: nil)
        xpath_select(xml, "//entry", limit:) do |entry|
          {
            title: xpath_text(entry, "title"),
            link: entry.at_xpath("link")&.[]("href"),
            description: xpath_text(entry, "summary") || xpath_text(entry, "content")
          }
        end
      end
    end
  end
end
