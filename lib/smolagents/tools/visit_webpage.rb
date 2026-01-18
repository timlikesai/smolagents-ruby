require "reverse_markdown"
require_relative "support"

module Smolagents
  module Tools
    # Web page fetching tool that converts HTML to readable markdown.
    #
    # Uses the Http concern for secure fetching (SSRF protection, etc.)
    # and ReverseMarkdown for HTML-to-Markdown conversion. Content is
    # automatically truncated to avoid overwhelming agent context.
    #
    # @example Creating and inspecting the tool
    #   tool = Smolagents::VisitWebpageTool.new(max_length: 10_000)
    #   tool.name
    #   # => "visit_webpage"
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
      include Support::ErrorHandling

      # TODO: Consider https://github.com/microsoft/markitdown if Ruby support is added

      self.tool_name = "visit_webpage"
      self.description = <<~DESC.strip
        Fetch a webpage and convert its content to readable markdown text.
        Handles HTML parsing, removes navigation/ads, and preserves main content.

        Use when: You have a specific URL and need to read its full content.
        Do NOT use: For searching - use a search tool first to find relevant URLs.

        Returns: Markdown-formatted page content (truncated if very long).
      DESC
      self.inputs = { url: { type: "string", description: "Full URL starting with http:// or https://" } }
      self.output_type = "string"

      # Immutable configuration (Ruby 4.0 Data.define pattern)
      Config = Data.define(:max_length_bytes, :timeout_seconds) do
        # Converts webpage tool configuration to a Hash for use in initialization.
        #
        # @return [Hash{Symbol => Object}] Hash with :max_length and :timeout keys
        def to_h = { max_length: max_length_bytes, timeout: timeout_seconds }
      end

      # Mutable DSL builder for configure blocks
      class ConfigBuilder
        def initialize = @settings = { max_length_bytes: 40_000, timeout_seconds: 20 }

        # Sets the maximum content length in bytes before truncation.
        #
        # @param bytes [Integer] Maximum content length in bytes
        # @return [Integer] The length that was set
        def max_length(bytes) = @settings[:max_length_bytes] = bytes

        # Sets the HTTP request timeout in seconds.
        #
        # @param seconds [Integer] Timeout duration in seconds
        # @return [Integer] The timeout that was set
        def timeout(seconds) = @settings[:timeout_seconds] = seconds

        # Builds the immutable Config from current settings.
        #
        # @return [Config] An immutable configuration object
        def build = Config.new(**@settings)
      end

      class << self
        # DSL block for configuring webpage fetching settings at the class level.
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
      def execute(url:)
        with_error_handling do
          response = get(url)
          body = sanitize_utf8(response.body)
          content = ReverseMarkdown.convert(body, unknown_tags: :bypass, github_flavored: true)
          truncate(content.gsub(/\n{3,}/, "\n\n").strip)
        end
      end

      private

      def sanitize_utf8(string)
        return "" if string.nil?

        string.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
      end

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
