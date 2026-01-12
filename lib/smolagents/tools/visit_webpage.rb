require "reverse_markdown"

module Smolagents
  class VisitWebpageTool < Tool
    include Concerns::Http

    # TODO: Consider https://github.com/microsoft/markitdown if Ruby support is added

    self.tool_name = "visit_webpage"
    self.description = "Fetch and read a webpage. Returns the page content as markdown text."
    self.inputs = { url: { type: "string", description: "Full URL of the page to read" } }
    self.output_type = "string"

    def initialize(max_length: 40_000)
      super()
      @max_length = max_length
      @timeout = 20
    end

    def execute(url:)
      response = get(url)
      content = ReverseMarkdown.convert(response.body, unknown_tags: :bypass, github_flavored: true)
      truncate(content.gsub(/\n{3,}/, "\n\n").strip)
    rescue Faraday::TimeoutError
      "Request timed out."
    rescue Faraday::Error => e
      "Error: #{e.message}"
    end

    private

    def truncate(content)
      return content if content.length <= @max_length

      "#{content[0...@max_length]}\n..._Truncated_..."
    end
  end
end
