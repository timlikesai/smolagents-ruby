module Smolagents
  module Config
    # Manages library-wide configuration settings.
    #
    # Provides a mutable configuration object with validation, freezing,
    # and reset capabilities. All configuration changes are validated
    # against {VALIDATORS} before being stored.
    #
    # Configuration can be accessed and modified in several ways:
    # - Via {Smolagents.configuration} singleton
    # - Via {Smolagents.configure} block
    # - By directly modifying Smolagents::Configuration instance
    #
    # All configuration attributes have validators that run on modification.
    # Invalid values raise ArgumentError immediately.
    #
    # @example Basic configuration
    #   Smolagents.configure do |config|
    #     config.max_steps = 30
    #     config.log_level = :debug
    #     config.log_format = :json
    #   end
    #
    # @example Freezing configuration for production
    #   config = Smolagents.configuration
    #   config.freeze!
    #   config.max_steps = 50  # raises FrozenError
    #
    # @example Validation
    #   Smolagents.configuration.validate!  # raises if invalid
    #   Smolagents.configuration.valid?     # returns boolean
    #
    # @example Resetting to defaults
    #   config = Smolagents.configuration
    #   config.reset!  # Back to defaults
    #
    # @example Creating independent copy
    #   copy = Smolagents.configuration.dup.freeze  # Frozen copy
    #
    # @api public
    #
    # @see Smolagents.configuration Global configuration instance
    # @see Smolagents.configure Block-based configuration
    # @see DEFAULTS Default configuration values
    # @see VALIDATORS Validation rules
    #
    class Configuration
      # @return [Array<String>] Default authorized imports (alias for Config::AUTHORIZED_IMPORTS)
      DEFAULT_AUTHORIZED_IMPORTS = AUTHORIZED_IMPORTS

      # @!attribute [r] max_steps
      #   @return [Integer] Maximum number of agent execution steps
      # @!attribute [r] custom_instructions
      #   @return [String, nil] Custom instructions for agent behavior
      # @!attribute [r] authorized_imports
      #   @return [Array<String>] Ruby libraries allowed in agent code execution
      # @!attribute [r] audit_logger
      #   @return [Object, nil] Logger for audit events
      # @!attribute [r] log_format
      #   @return [Symbol] Output format (:text or :json)
      # @!attribute [r] log_level
      #   @return [Symbol] Logging verbosity (:debug, :info, :warn, :error)
      # @!attribute [r] frozen
      #   @return [Boolean] Whether configuration is frozen
      # @!attribute [r] model_palette
      #   @return [ModelPalette] Registry for named model factories
      attr_reader(*DEFAULTS.keys, :frozen, :model_palette)
      alias frozen? frozen

      # Environment variable mappings for auto-configuration.
      # Values are loaded on reset! and can be overridden via configure block.
      ENV_MAPPINGS = {
        search_provider: { env: "SMOLAGENTS_SEARCH_PROVIDER", transform: :to_sym },
        searxng_url: { env: "SEARXNG_URL" }
      }.freeze

      # Creates a new configuration with default values.
      def initialize
        @model_palette = ModelPalette.create
        reset!
      end

      DEFAULTS.each_key do |attr|
        define_method(:"#{attr}=") do |value|
          raise FrozenError, "Configuration is frozen" if @frozen

          VALIDATORS[attr]&.call(value)
          instance_variable_set(:"@#{attr}", value)
        end
      end

      # Freezes this configuration, preventing further modifications.
      # @return [self]
      # @raise [FrozenError] on subsequent modification attempts
      def freeze! = (@frozen = true) && self

      # Returns a frozen duplicate of this configuration.
      # @return [Configuration] frozen copy
      def freeze = dup.freeze!

      # Resets this configuration to default values.
      # Also loads values from environment variables (see ENV_MAPPINGS).
      # @return [self]
      def reset!
        DEFAULTS.each { |key, val| instance_variable_set(:"@#{key}", val.dup) }
        load_from_environment!
        @frozen = false
        self
      end

      # Returns a reset duplicate of this configuration.
      # @return [Configuration] reset copy
      def reset = dup.reset!

      # Validates all configuration values.
      # @return [true] if valid
      # @raise [ArgumentError] if any value is invalid
      def validate! = VALIDATORS.each { |key, validator| validator.call(instance_variable_get(:"@#{key}")) } && true

      # Checks if configuration is valid without raising.
      # @return [Boolean] true if valid, false otherwise
      def validate
        (validate!
         true)
      rescue ArgumentError => e
        warn "[Configuration#validate] validation failed: #{e.message}" if $DEBUG
        false
      end
      alias valid? validate

      # Configure model palette via block.
      #
      # @yield [ModelPalette] The palette to register models with
      # @return [ModelPalette]
      #
      # @example
      #   config.models do |m|
      #     m = m.register(:fast, -> { OpenAIModel.lm_studio("gemma") })
      #     m = m.register(:smart, -> { AnthropicModel.new("claude-sonnet-4-20250514") })
      #     m
      #   end
      def models
        check_frozen!
        @model_palette = yield(@model_palette)
      end

      private

      def check_frozen!
        raise FrozenError, "Configuration is frozen" if @frozen
      end

      def load_from_environment!
        ENV_MAPPINGS.each do |attr, opts|
          env_value = ENV.fetch(opts[:env], nil)
          next unless env_value && !env_value.empty?

          value = opts[:transform] ? env_value.public_send(opts[:transform]) : env_value
          instance_variable_set(:"@#{attr}", value)
        end
      end
    end
  end

  class << self
    # @return [Config::Configuration] the global configuration instance
    def configuration = @configuration ||= Config::Configuration.new

    # Yields the configuration for modification.
    # @yieldparam config [Config::Configuration] the configuration object
    # @return [Config::Configuration] the configuration object
    def configure = yield(configuration) && configuration

    # Resets the global configuration to defaults.
    # @return [Config::Configuration] the reset configuration
    def reset_configuration! = configuration.reset!

    # @return [Object, nil] the configured audit logger
    def audit_logger = configuration.audit_logger

    # Get a registered model by name.
    #
    # @param name [Symbol] Model role name
    # @return [Model] New model instance
    def get_model(name)
      configuration.model_palette.get(name)
    end
  end

  # @!parse
  #   # Re-exported for convenience. See {Config::Configuration}.
  #   Configuration = Config::Configuration
  Configuration = Config::Configuration
end
