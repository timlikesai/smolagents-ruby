module Smolagents
  module Concerns
    module Support
      # Browser-like request headers for HTTP tools.
      #
      # Provides headers that mimic a real browser to avoid blocks
      # from sites that reject bot-like requests.
      #
      # @example Include for browser-like requests
      #   class MyTool < Tool
      #     include Concerns::Support::BrowserMode
      #
      #     def execute(url:)
      #       response = get(url, headers: browser_headers)
      #     end
      #   end
      module BrowserMode
        USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                     "AppleWebKit/537.36 (KHTML, like Gecko) " \
                     "Chrome/120.0.0.0 Safari/537.36".freeze

        ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".freeze
        ACCEPT_LANGUAGE = "en-US,en;q=0.9".freeze

        # Returns browser-like headers for HTTP requests.
        # @return [Hash] Headers hash
        def browser_headers
          {
            "User-Agent" => USER_AGENT,
            "Accept" => ACCEPT,
            "Accept-Language" => ACCEPT_LANGUAGE
          }.freeze
        end

        # Browser type configuration (for logging/debugging).
        # @return [Symbol] Always :chrome
        def browser_type = :chrome

        # Headless mode configuration (for logging/debugging).
        # @return [Boolean] Always true for HTTP-only mode
        def headless? = true
      end
    end
  end
end
