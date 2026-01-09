# frozen_string_literal: true

require "faraday"
require "nokogiri"

module Smolagents
  module DefaultTools
    # Tool for visiting webpages and extracting content as markdown.
    # Fetches webpage HTML and converts to readable markdown format.
    class VisitWebpageTool < Tool
      self.tool_name = "visit_webpage"
      self.description = "Visits a webpage at the given URL and reads its content as a markdown string. Use this to browse webpages."
      self.inputs = {
        "url" => {
          "type" => "string",
          "description" => "The URL of the webpage to visit."
        }
      }
      self.output_type = "string"

      # Initialize visit webpage tool.
      #
      # @param max_output_length [Integer] maximum content length in characters
      def initialize(max_output_length: 40_000)
        super()
        @max_output_length = max_output_length
      end

      # Visit a webpage and extract its content.
      #
      # @param url [String] URL to visit
      # @return [String] webpage content as markdown
      def forward(url:)
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end

        response = conn.get(url) do |req|
          req.options.timeout = 20
        end

        # Parse HTML and convert to markdown-like format
        markdown_content = html_to_markdown(response.body)

        # Remove excessive line breaks
        markdown_content = markdown_content.gsub(/\n{3,}/, "\n\n")

        truncate_content(markdown_content, @max_output_length)
      rescue Faraday::TimeoutError
        "The request timed out. Please try again later or check the URL."
      rescue Faraday::Error => e
        "Error fetching the webpage: #{e.message}"
      rescue StandardError => e
        "An unexpected error occurred: #{e.message}"
      end

      private

      # Convert HTML to simplified markdown format.
      #
      # @param html [String] HTML content
      # @return [String] markdown-like text
      def html_to_markdown(html)
        doc = Nokogiri::HTML(html)

        # Remove script and style elements
        doc.css("script, style").each(&:remove)

        # Extract main content (try common article selectors)
        content = doc.at_css("article, main, .content, #content") || doc.at_css("body")

        return "" unless content

        # Convert to markdown-like format
        markdown = content.css("h1").map { |h| "\n# #{h.text.strip}\n" }
        content.css("h2").each { |h| markdown << "\n## #{h.text.strip}\n" }
        content.css("h3").each { |h| markdown << "\n### #{h.text.strip}\n" }
        content.css("h4").each { |h| markdown << "\n#### #{h.text.strip}\n" }

        content.css("p").each { |p| markdown << "\n#{p.text.strip}\n" }

        content.css("li").each { |li| markdown << "- #{li.text.strip}\n" }

        content.css("a").each do |a|
          text = a.text.strip
          href = a["href"]
          markdown << "[#{text}](#{href})" if text && href
        end

        # Fallback: just get all text if structured extraction failed
        if markdown.empty?
          content.text.strip
        else
          markdown.join
        end
      end

      # Truncate content to maximum length.
      #
      # @param content [String] content to truncate
      # @param max_length [Integer] maximum length
      # @return [String] truncated content
      def truncate_content(content, max_length)
        return content if content.length <= max_length

        content[0...max_length] +
          "\n..._This content has been truncated to stay below #{max_length} characters_...\n"
      end
    end
  end
end
