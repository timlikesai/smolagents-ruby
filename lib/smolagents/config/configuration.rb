module Smolagents
  module Config
    # Manages library-wide configuration settings.
    #
    # Provides a mutable configuration object with validation, freezing,
    # and reset capabilities. Access via {Smolagents.configuration} or
    # {Smolagents.configure}.
    #
    # @example Basic configuration
    #   Smolagents.configure do |config|
    #     config.max_steps = 30
    #     config.log_level = :debug
    #     config.log_format = :json
    #   end
    #
    # @example Freezing configuration
    #   config = Smolagents.configuration
    #   config.freeze!
    #   config.max_steps = 50  # raises FrozenError
    #
    # @example Validation
    #   Smolagents.configuration.validate!  # raises if invalid
    #   Smolagents.configuration.valid?     # returns boolean
    #
    # @api public
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
      attr_reader(*DEFAULTS.keys, :frozen)
      alias frozen? frozen

      # Creates a new configuration with default values.
      def initialize = reset!

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
      # @return [self]
      def reset! = DEFAULTS.each { |key, val| instance_variable_set(:"@#{key}", val.dup) } && (@frozen = false) && self

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
  end

  # @!parse
  #   # Re-exported for convenience. See {Config::Configuration}.
  #   Configuration = Config::Configuration
  Configuration = Config::Configuration
end
