# frozen_string_literal: true

require "nokogiri"

module Smolagents
  module Concerns
    module Html
      def parse_html(content)
        Nokogiri::HTML(content)
      end

      def css_select(doc_or_html, selector, limit: nil, &)
        doc = doc_or_html.is_a?(String) ? parse_html(doc_or_html) : doc_or_html
        elements = doc.css(selector)
        elements = elements.take(limit) if limit
        block_given? ? elements.filter_map(&) : elements
      end

      def strip_html_tags(text)
        text&.gsub(/<[^>]+>/, "")&.strip || ""
      end

      def text_content(element)
        element&.text&.strip
      end

      def attr_value(element, attr)
        element&.[](attr)
      end
    end
  end
end
