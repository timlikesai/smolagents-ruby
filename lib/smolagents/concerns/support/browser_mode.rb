module Smolagents
  module Concerns
    module Support
      # Browser mode concern for tools that need to evade bot detection.
      #
      # Some services (like DuckDuckGo lite) block bot User-Agents and require
      # browser-like headers to accept requests. Include this concern and call
      # setup_browser_mode in your tool's initializer.
      #
      # @example
      #   class MyScrapingTool < Tool
      #     include Concerns::BrowserMode
      #
      #     def initialize(**)
      #       super
      #       setup_browser_mode
      #     end
      #   end
      module BrowserMode
        # Standard browser User-Agent for sites that block bots.
        # Chrome on Windows - widely accepted, stable version string.
        BROWSER_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                             "AppleWebKit/537.36 (KHTML, like Gecko) " \
                             "Chrome/120.0.0.0 Safari/537.36".freeze

        # Browser-like headers to avoid heuristic bot detection.
        BROWSER_HEADERS = {
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
          "Accept-Language" => "en-US,en;q=0.5",
          "Accept-Encoding" => "gzip, deflate, br",
          "DNT" => "1",
          "Connection" => "keep-alive",
          "Upgrade-Insecure-Requests" => "1",
          "Sec-Fetch-Dest" => "document",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Site" => "none",
          "Sec-Fetch-User" => "?1",
          "Cache-Control" => "max-age=0"
        }.freeze

        protected

        def setup_browser_mode
          @user_agent = BROWSER_USER_AGENT
          @browser_headers = BROWSER_HEADERS
        end

        def browser_headers_if_enabled
          return {} unless defined?(@browser_headers) && @browser_headers

          @browser_headers.dup
        end
      end
    end
  end
end
