module Smolagents
  module Config
    class Configuration
      # Loads configuration values from environment variables.
      #
      # Provides a declarative mapping between environment variable names
      # and configuration attributes, with optional value transformation.
      #
      # @api private
      module Environment
        # Environment variable mappings for auto-configuration.
        # Values are loaded on reset! and can be overridden via configure block.
        #
        # @return [Hash{Symbol => Hash}] Mapping of attribute to env config
        ENV_MAPPINGS = {
          search_provider: { env: "SMOLAGENTS_SEARCH_PROVIDER", transform: :to_sym },
          searxng_url: { env: "SEARXNG_URL" }
        }.freeze

        private

        # Loads values from environment variables based on ENV_MAPPINGS.
        #
        # Each mapping specifies:
        # - :env - The environment variable name to read
        # - :transform - Optional method to call on the value (e.g., :to_sym)
        #
        # @return [void]
        def load_from_environment!
          ENV_MAPPINGS.each do |attr, opts|
            env_value = ENV.fetch(opts[:env], nil)
            next unless env_value && !env_value.empty?

            value = opts[:transform] ? env_value.public_send(opts[:transform]) : env_value
            instance_variable_set(:"@#{attr}", freeze_value(value))
          end
        end
      end
    end
  end
end
