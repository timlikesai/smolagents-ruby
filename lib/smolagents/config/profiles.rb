module Smolagents
  module Config
    # Profile registry and application for configuration presets.
    #
    # Manages named {Types::ConfigProfile} instances and applies their overrides
    # to {Configuration} objects. Built-in profiles are registered on first
    # access: +:local_gpu+, +:development+, +:cloud_api+, and +:default+.
    #
    # @example Applying a built-in profile
    #   Smolagents::Config::Profiles.apply(:local_gpu, configuration)
    #
    # @example Registering a custom profile
    #   Smolagents::Config::Profiles.register(
    #     Types::ConfigProfile.new(name: :staging, description: "Staging", overrides: { max_steps: 15 })
    #   )
    #
    # @see Types::ConfigProfile For the profile data type
    module Profiles
      class << self
        # Register a profile in the registry.
        #
        # @param profile [Types::ConfigProfile] The profile to register
        # @return [Types::ConfigProfile] the registered profile
        def register(profile) = registry[profile.name] = profile

        # Retrieve a profile by name.
        #
        # @param name [Symbol] Profile name
        # @return [Types::ConfigProfile, nil]
        def [](name) = registry[name]

        # All registered profile names.
        #
        # @return [Array<Symbol>]
        def names = registry.keys

        # Whether a profile is registered.
        #
        # @param name [Symbol]
        # @return [Boolean]
        def registered?(name) = registry.key?(name)

        # Apply a named profile's overrides to a configuration.
        #
        # @param name [Symbol] Profile name
        # @param config [Configuration] Configuration to modify
        # @return [Configuration] the modified configuration
        # @raise [ArgumentError] If profile not found
        def apply(name, config)
          profile = fetch_profile!(name)
          apply_overrides(profile.overrides, config)
          config
        end

        # Reset registry to built-in profiles only.
        #
        # @return [void]
        def reset!
          @registry = nil
        end

        private

        def registry
          @registry ||= build_defaults
        end

        def fetch_profile!(name)
          registry.fetch(name) do
            raise ArgumentError, "Unknown profile: #{name}. Available: #{names.join(", ")}"
          end
        end

        def build_defaults
          {}.tap do |reg|
            [
              Smolagents::Types::ConfigProfile.local_gpu,
              Smolagents::Types::ConfigProfile.development,
              Smolagents::Types::ConfigProfile.cloud_api,
              Smolagents::Types::ConfigProfile.default
            ].each { |p| reg[p.name] = p }
          end
        end

        def apply_overrides(overrides, config)
          overrides.each do |key, value|
            setter = :"#{key}="
            config.send(setter, value) if config.respond_to?(setter)
          end
        end
      end
    end
  end
end
