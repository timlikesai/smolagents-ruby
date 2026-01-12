require "reverse_markdown"

module Smolagents
  # Web page fetching tool that converts HTML to readable markdown.
  #
  # Uses the Http concern for secure fetching (SSRF protection, etc.)
  # and ReverseMarkdown for HTML-to-Markdown conversion. Content is
  # automatically truncated to avoid overwhelming agent context.
  #
  # @example Basic usage
  #   tool = VisitWebpageTool.new
  #   result = tool.call(url: "https://example.com")
  #   # => Markdown-formatted page content
  #
  # @example In a search-then-visit pipeline
  #   Smolagents.pipeline
  #     .call(:duckduckgo_search, query: :input)
  #     .then(:visit_webpage) { |r| { url: r.first[:link] } }
  #     .run(input: "Ruby programming")
  #
  # @example With custom max_length
  #   tool = VisitWebpageTool.new(max_length: 10_000)
  #
  # @example In AgentBuilder
  #   agent = Smolagents.agent(:tool_calling)
  #     .model { my_model }
  #     .tools(:duckduckgo_search, :visit_webpage, :final_answer)
  #     .build
  #
  # Security:
  # - SSRF protection via Http concern (blocks private IPs, cloud metadata)
  # - DNS rebinding protection
  # - 20-second timeout
  #
  # @see Http Security concern with SSRF protection
  # @see DuckDuckGoSearchTool Often used together for search-then-fetch patterns
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
