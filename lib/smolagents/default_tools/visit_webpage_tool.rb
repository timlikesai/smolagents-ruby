# frozen_string_literal: true

require "nokogiri"

module Smolagents
  module DefaultTools
    # Tool for visiting webpages and extracting content as markdown.
    class VisitWebpageTool < Tool
      include Concerns::HttpClient

      self.tool_name = "visit_webpage"
      self.description = "Visits a webpage at the given URL and reads its content as markdown. Use this to browse webpages."
      self.inputs = { "url" => { "type" => "string", "description" => "The URL of the webpage to visit." } }
      self.output_type = "string"

      def initialize(max_output_length: 40_000)
        super()
        @max_output_length = max_output_length
        @timeout = 20
      end

      def forward(url:)
        response = http_get(url)
        content = html_to_markdown(response.body).gsub(/\n{3,}/, "\n\n")
        truncate(content)
      rescue Faraday::TimeoutError
        "The request timed out. Please try again later or check the URL."
      rescue Faraday::Error => e
        "Error fetching the webpage: #{e.message}"
      end

      private

      def html_to_markdown(html)
        doc = Nokogiri::HTML(html)
        doc.css("script, style").each(&:remove)
        content = doc.at_css("article, main, .content, #content") || doc.at_css("body")
        return "" unless content

        markdown = []
        %w[h1 h2 h3 h4].each_with_index { |tag, i| content.css(tag).each { |h| markdown << "\n#{"#" * (i + 1)} #{h.text.strip}\n" } }
        content.css("p").each { |p| markdown << "\n#{p.text.strip}\n" }
        content.css("li").each { |li| markdown << "- #{li.text.strip}\n" }
        content.css("a").each { |a| markdown << "[#{a.text.strip}](#{a["href"]})" if a.text.strip.length.positive? && a["href"] }

        markdown.empty? ? content.text.strip : markdown.join
      end

      def truncate(content)
        return content if content.length <= @max_output_length

        "#{content[0...@max_output_length]}\n..._Truncated to #{@max_output_length} characters_..."
      end
    end
  end
end
