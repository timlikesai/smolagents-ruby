module Smolagents
  module Config
    class Configuration
      # Provides freeze and reset capabilities for configuration.
      #
      # A frozen configuration prevents all modifications, making it
      # safe for use in concurrent environments. Reset restores all
      # values to defaults and unfreezes the configuration.
      #
      # @api private
      module Freezable
        # @!attribute [r] frozen
        #   @return [Boolean] Whether configuration is frozen
        def self.included(base)
          base.attr_reader :frozen
          base.alias_method :frozen?, :frozen
        end

        # Freezes this configuration, preventing further modifications.
        #
        # @return [self]
        # @raise [FrozenError] on subsequent modification attempts
        def freeze! = (@frozen = true) && self

        # Returns a frozen duplicate of this configuration.
        #
        # @return [Configuration] frozen copy
        def freeze = dup.freeze!

        # Resets this configuration to default values.
        # Also loads values from environment variables (see Environment).
        #
        # @return [self]
        def reset!
          DEFAULTS.each { |key, val| instance_variable_set(:"@#{key}", val.dup) }
          load_from_environment!
          @frozen = false
          self
        end

        # Returns a reset duplicate of this configuration.
        #
        # @return [Configuration] reset copy
        def reset = dup.reset!

        private

        def check_frozen!
          raise FrozenError, "Configuration is frozen" if @frozen
        end
      end
    end
  end
end
