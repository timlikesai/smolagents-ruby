require_relative "configuration/value_freezer"
require_relative "configuration/environment"
require_relative "configuration/freezable"
require_relative "configuration/attributes"
require_relative "configuration/validation"

module Smolagents
  module Config
    # Manages library-wide configuration settings.
    #
    # Provides a mutable configuration object with validation, freezing,
    # and reset capabilities. All configuration changes are validated
    # against {VALIDATORS} before being stored.
    #
    # @example Basic configuration
    #   Smolagents.configure do |config|
    #     config.max_steps = 30
    #     config.log_level = :debug
    #   end
    #
    # @example Freezing configuration for production
    #   config = Smolagents.configuration
    #   config.freeze!
    #   config.max_steps = 50  # raises FrozenError
    #
    # @see Smolagents.configuration Global configuration instance
    # @see DEFAULTS Default configuration values
    # @see VALIDATORS Validation rules
    #
    # @api public
    class Configuration
      # @return [Array<String>] Default authorized imports (alias for Config::AUTHORIZED_IMPORTS)
      DEFAULT_AUTHORIZED_IMPORTS = AUTHORIZED_IMPORTS

      include ValueFreezer
      include Environment
      include Freezable
      include Attributes
      include Validation

      # @!attribute [r] model_palette
      #   @return [ModelPalette] Registry for named model factories
      attr_reader :model_palette

      # Creates a new configuration with default values.
      def initialize
        @model_palette = ModelPalette.create
        reset!
      end

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
    end
  end

  class << self
    # @return [Config::Configuration] the global configuration instance
    def configuration = @configuration ||= Config::Configuration.new

    # Yields the configuration for modification.
    #
    # Emits a ConfigurationChanged event after the block completes.
    #
    # @yieldparam config [Config::Configuration] the configuration object
    # @return [Config::Configuration] the configuration object
    def configure
      yield(configuration)
      emit_configuration_changed
      configuration
    end

    private

    def emit_configuration_changed
      return unless defined?(Events::ConfigurationChanged)

      # Use the global event emitter if available
      Events::Emitter.emit(Events::ConfigurationChanged.create) if Events::Emitter.respond_to?(:emit)
    end

    public

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
