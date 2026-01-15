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
