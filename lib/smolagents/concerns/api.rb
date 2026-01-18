require_relative "api/keys"
require_relative "api/http"
require_relative "api/client"

module Smolagents
  module Concerns
    # Unified API concern for external service interaction.
    #
    # Combines API key management, HTTP client with SSRF protection,
    # and resilient API call patterns into a single composable concern.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern   | Depends On          | Depended By | Auto-Includes |
    #   |-----------|---------------------|-------------|---------------|
    #   | ApiKey    | -                   | Api         | -             |
    #   | Http      | net/http (stdlib)   | Api         | -             |
    #   | ApiClient | Http, Auditable     | Api         | -             |
    #   | Api       | ApiKey, Http,       | -           | ApiKey, Http, |
    #   |           | ApiClient           |             | ApiClient     |
    #
    # == Sub-concern Methods
    #
    #   ApiKey
    #       +-- require_api_key(key, env_var:) - Get key from param or ENV
    #       +-- optional_api_key(key, env_var:) - Get key, nil if missing
    #       +-- api_key_present?(env_var:) - Check if key is available
    #
    #   Http
    #       +-- get(url, params: {}, headers: {}) - HTTP GET request
    #       +-- post(url, body:, headers: {}) - HTTP POST request
    #       +-- http_client - Get/build HTTP client instance
    #       +-- validate_url!(url) - SSRF protection check
    #
    #   ApiClient
    #       +-- api_call(service:, operation:, &block) - Audited API call
    #       +-- api_request(method:, url:, **) - Low-level request
    #
    # == Instance Variables Set
    #
    # *Http*:
    # - @http_client [Net::HTTP] - Reusable HTTP client
    # - @http_options [Hash] - Default HTTP options (timeout, etc.)
    #
    # *ApiKey*:
    # - @api_key [String] - Resolved API key (set by caller)
    #
    # == Security Features
    #
    # *Http*:
    # - SSRF protection via URL validation (blocks private IPs)
    # - Configurable timeouts (default: 30s)
    # - TLS verification enabled by default
    #
    # *ApiKey*:
    # - Environment variable fallback (secrets out of code)
    # - Clear error messages for missing keys
    #
    # @!endgroup
    #
    # @example Tool with full API support
    #   class MyApiTool < Tool
    #     include Concerns::Api
    #
    #     def initialize(api_key: nil, **)
    #       super()
    #       @api_key = require_api_key(api_key, env_var: "MY_API_KEY")
    #     end
    #
    #     def execute(query:)
    #       api_call(service: "my_api", operation: "search") do
    #         get("https://api.example.com/search", params: { q: query })
    #       end
    #     end
    #   end
    #
    # @see ApiKey For API key resolution
    # @see Http For HTTP client functionality
    # @see ApiClient For resilient API call patterns
    module Api
      include ApiKey
      include Http
      include ApiClient
    end
  end
end
