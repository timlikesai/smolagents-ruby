# frozen_string_literal: true

require "nokogiri"

module Smolagents
  class VisitWebpageTool < Tool
    include Concerns::Http

    self.tool_name = "visit_webpage"
    self.description = "Fetch and read a webpage. Returns the page content as markdown text."
    self.inputs = { url: { type: "string", description: "Full URL of the page to read" } }
    self.output_type = "string"

    def initialize(max_length: 40_000)
      super()
      @max_length = max_length
      @timeout = 20
    end

    def forward(url:)
      response = get(url)
      content = html_to_markdown(response.body).gsub(/\n{3,}/, "\n\n")
      truncate(content)
    rescue Faraday::TimeoutError
      "Request timed out."
    rescue Faraday::Error => e
      "Error: #{e.message}"
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
      return content if content.length <= @max_length

      "#{content[0...@max_length]}\n..._Truncated_..."
    end
  end
end
