require "reverse_markdown"

module Smolagents
  module Tools
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
    # @example With custom max_length (instance level)
    #   tool = VisitWebpageTool.new(max_length: 10_000)
    #
    # @example Custom subclass via DSL
    #   class CompactWebpageTool < VisitWebpageTool
    #     configure do
    #       max_length 5_000
    #       timeout 10
    #     end
    #   end
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
    # - Configurable timeout (default 20 seconds)
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

      # Immutable configuration (Ruby 4.0 Data.define pattern)
      Config = Data.define(:max_length_bytes, :timeout_seconds) do
        def to_h = { max_length: max_length_bytes, timeout: timeout_seconds }
      end

      # Mutable DSL builder for configure blocks
      class ConfigBuilder
        def initialize = @settings = { max_length_bytes: 40_000, timeout_seconds: 20 }
        def max_length(bytes) = @settings[:max_length_bytes] = bytes
        def timeout(seconds) = @settings[:timeout_seconds] = seconds
        def build = Config.new(**@settings)
      end

      class << self
        # DSL block for configuring webpage fetching settings at the class level.
        #
        # @example
        #   class SmallPageTool < VisitWebpageTool
        #     configure do
        #       max_length 5_000
        #       timeout 10
        #     end
        #   end
        #
        # @yield Configuration block
        # @return [Config] The configuration
        def configure(&block)
          builder = ConfigBuilder.new
          builder.instance_eval(&block) if block
          @config = builder.build
        end

        # Returns the configuration, inheriting from parent if not set.
        # @return [Config] Always returns a Config
        def config
          @config ||
            (superclass.config if superclass.respond_to?(:config)) ||
            ConfigBuilder.new.build
        end
      end

      # @return [Integer] Maximum content length in bytes
      attr_reader :max_length

      # Creates a new webpage fetching tool.
      #
      # @param max_length [Integer] Maximum content length before truncation (default: 40_000)
      # @param timeout [Integer] Request timeout in seconds (default: 20)
      def initialize(max_length: nil, timeout: nil)
        config = self.class.config.to_h
        @max_length = max_length || config[:max_length]
        @timeout = timeout || config[:timeout]
        super()
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

  # Re-export VisitWebpageTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::VisitWebpageTool
  VisitWebpageTool = Tools::VisitWebpageTool
end
