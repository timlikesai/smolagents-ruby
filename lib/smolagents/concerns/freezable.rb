module Smolagents
  module Concerns
    # Shared frozen state checking for immutable configurations.
    #
    # Provides a standard `check_frozen!` method that raises FrozenError
    # when modifications are attempted on frozen objects.
    #
    # == Usage
    #
    # Include this module and implement a `frozen?` predicate method:
    #
    #   class MyConfig
    #     include Smolagents::Concerns::Freezable
    #
    #     def frozen?
    #       @frozen == true
    #     end
    #
    #     def set_value(val)
    #       check_frozen!
    #       @value = val
    #     end
    #   end
    #
    # == Customizing the Error Message
    #
    # Override `frozen_error_message` to customize the FrozenError message:
    #
    #   def frozen_error_message
    #     "Cannot modify frozen #{self.class.name}"
    #   end
    #
    # @see Builders::Base Uses for builder pattern freezing
    # @see Config::Configuration::Freezable Uses for configuration freezing
    module Freezable
      # Raise FrozenError if the object is frozen.
      #
      # @return [void]
      # @raise [FrozenError] If frozen? returns true
      def check_frozen!
        raise FrozenError, frozen_error_message if frozen?
      end

      private

      # Error message for FrozenError.
      # Override to customize.
      #
      # @return [String] The error message
      def frozen_error_message = "Configuration is frozen"
    end
  end
end
