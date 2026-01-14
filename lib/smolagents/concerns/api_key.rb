module Smolagents
  module Concerns
    # API key handling utilities for tools that require authentication.
    #
    # Provides methods for resolving API keys from arguments or environment
    # variables, with both required and optional modes.
    #
    # @example Require an API key
    #   class MyApiTool < Tool
    #     include Concerns::ApiKey
    #
    #     def initialize(api_key: nil, **)
    #       super()
    #       @api_key = require_api_key(api_key, env_var: "MY_API_KEY")
    #     end
    #   end
    #
    # @example Optional API key (e.g., for free tier vs paid)
    #   @api_key = optional_api_key(api_key, env_var: "OPTIONAL_KEY")
    #   if @api_key
    #     # Use authenticated endpoint
    #   else
    #     # Use public endpoint
    #   end
    #
    # @example Multi-provider configuration
    #   PROVIDERS = {
    #     "openai" => { url: "https://api.openai.com", key_env: "OPENAI_API_KEY" },
    #     "anthropic" => { url: "https://api.anthropic.com", key_env: "ANTHROPIC_API_KEY" }
    #   }
    #
    #   def initialize(provider: "openai", api_key: nil)
    #     config, @api_key = configure_provider(provider, PROVIDERS, api_key: api_key)
    #     @base_url = config[:url]
    #   end
    #
    # @see SearchTool Which includes this for API-based search tools
    # @see Http For making authenticated HTTP requests
    module ApiKey
      # Resolve a required API key from argument or environment.
      # @param key [String, nil] Explicitly provided API key
      # @param env_var [String] Environment variable name to check
      # @param name [String, nil] Human-readable name for error messages
      # @return [String] The resolved API key
      # @raise [ArgumentError] If no API key is found
      def require_api_key(key, env_var:, name: nil)
        api_key = key || ENV.fetch(env_var, nil)
        raise ArgumentError, "Missing API key: #{name || env_var}" unless api_key

        api_key
      end

      # Resolve an optional API key from argument or environment.
      # @param key [String, nil] Explicitly provided API key
      # @param env_var [String] Environment variable name to check
      # @return [String, nil] The resolved API key or nil if not found
      def optional_api_key(key, env_var:)
        key || ENV.fetch(env_var, nil)
      end

      # Configure a provider with its API key.
      # @param provider [String, Symbol] Provider name to look up
      # @param providers [Hash] Provider configurations with :key_env or :env keys
      # @param api_key [String, nil] Explicitly provided API key
      # @param required [Boolean] Whether API key is required (default: true)
      # @return [Array(Hash, String)] Tuple of [provider_config, resolved_api_key]
      # @raise [ArgumentError] If provider is unknown or required key is missing
      def configure_provider(provider, providers, api_key: nil, required: true)
        config = providers.fetch(provider.to_s) { raise ArgumentError, "Unknown provider: #{provider}" }
        env_var = config[:key_env] || config[:env]
        resolved_key = required ? require_api_key(api_key, env_var:) : optional_api_key(api_key, env_var:)
        [config, resolved_key]
      end
    end
  end
end
