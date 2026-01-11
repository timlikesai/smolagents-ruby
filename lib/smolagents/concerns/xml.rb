require "nokogiri"

module Smolagents
  module Concerns
    module Xml
      def parse_xml(content)
        Nokogiri::XML(content)
      end

      def xpath_select(doc_or_xml, path, limit: nil)
        doc = doc_or_xml.is_a?(String) ? parse_xml(doc_or_xml) : doc_or_xml
        elements = doc.xpath(path)
        elements = elements.take(limit) if limit
        block_given? ? elements.filter_map { |el| yield(el) } : elements
      end

      def xpath_text(element, path)
        element.at_xpath(path)&.text&.strip
      end

      def parse_rss_items(xml, limit: nil)
        xpath_select(xml, "//item", limit: limit) do |item|
          {
            title: xpath_text(item, "title"),
            link: xpath_text(item, "link"),
            description: xpath_text(item, "description")
          }
        end
      end

      def parse_atom_entries(xml, limit: nil)
        xpath_select(xml, "//entry", limit: limit) do |entry|
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
