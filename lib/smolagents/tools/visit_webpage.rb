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
        # Converts webpage tool configuration to a Hash for use in initialization.
        #
        # @return [Hash{Symbol => Object}] Hash with :max_length and :timeout keys
        #
        # @example
        #   config = Config.new(max_length_bytes: 10_000, timeout_seconds: 15)
        #   config.to_h
        #   # => { max_length: 10_000, timeout: 15 }
        def to_h = { max_length: max_length_bytes, timeout: timeout_seconds }
      end

      # Mutable DSL builder for configure blocks
      class ConfigBuilder
        def initialize = @settings = { max_length_bytes: 40_000, timeout_seconds: 20 }

        # Sets the maximum content length in bytes before truncation.
        #
        # @param bytes [Integer] Maximum content length in bytes
        # @return [Integer] The length that was set
        #
        # @example
        #   builder.max_length(20_000)
        def max_length(bytes) = @settings[:max_length_bytes] = bytes

        # Sets the HTTP request timeout in seconds.
        #
        # @param seconds [Integer] Timeout duration in seconds
        # @return [Integer] The timeout that was set
        #
        # @example
        #   builder.timeout(10)
        def timeout(seconds) = @settings[:timeout_seconds] = seconds

        # Builds the immutable Config from current settings.
        #
        # @return [Config] An immutable configuration object
        #
        # @example
        #   builder.max_length(15_000)
        #   builder.timeout(25)
        #   config = builder.build
        #   # => Config with max_length_bytes=15_000, timeout_seconds=25
        def build = Config.new(**@settings)
      end

      class << self
        # DSL block for configuring webpage fetching settings at the class level.
        #
        # @example
        #   class SmallPageTool < VisitWebpageTool
        #     configure do |config|
        #       config.max_length 5_000
        #       config.timeout 10
        #     end
        #   end
        #
        # @yield [config] Configuration block with explicit builder parameter
        # @yieldparam config [ConfigBuilder] The configuration builder
        # @return [Config] The configuration
        def configure(&block)
          builder = ConfigBuilder.new
          block&.call(builder)
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

      # Fetches a webpage and converts its HTML content to readable markdown.
      #
      # The method uses the Http concern for secure fetching (SSRF protection, timeouts),
      # converts HTML to markdown via ReverseMarkdown, normalizes whitespace, and
      # truncates the result to the configured maximum length.
      #
      # On network errors, returns a descriptive error message rather than raising
      # an exception, allowing agents to handle failures gracefully.
      #
      # @param url [String] Full URL of the webpage to fetch
      # @return [String] Markdown-formatted page content (possibly truncated) or error message
      #
      # @example Successful fetch
      #   execute(url: "https://example.com")
      #   # => "# Example Domain\n\nThis domain is for use in examples..."
      #
      # @example Timeout error
      #   execute(url: "https://httpstat.us/200?sleep=30000")
      #   # => "Request timed out."
      #
      # @example Network error
      #   execute(url: "https://invalid-domain-12345.example")
      #   # => "Error: Failed to connect to..."
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
