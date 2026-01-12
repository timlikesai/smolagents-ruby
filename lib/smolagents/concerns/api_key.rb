module Smolagents
  module Concerns
    module ApiKey
      def require_api_key(key, env_var:, name: nil)
        api_key = key || ENV.fetch(env_var, nil)
        raise ArgumentError, "Missing API key: #{name || env_var}" unless api_key

        api_key
      end

      def optional_api_key(key, env_var:)
        key || ENV.fetch(env_var, nil)
      end

      def configure_provider(provider, providers, api_key: nil, required: true)
        config = providers.fetch(provider.to_s) { raise ArgumentError, "Unknown provider: #{provider}" }
        env_var = config[:key_env] || config[:env]
        resolved_key = required ? require_api_key(api_key, env_var: env_var) : optional_api_key(api_key, env_var: env_var)
        [config, resolved_key]
      end
    end
  end
end
