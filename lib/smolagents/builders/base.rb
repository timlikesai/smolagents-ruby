require_relative "base/metadata"
require_relative "base/validation"
require_relative "base/help"
require_relative "support/introspection"

module Smolagents
  module Builders
    # Core builder functionality for immutable, validated, REPL-friendly builders.
    #
    # Provides validation, help text generation, introspection, and freezing capabilities.
    # Include in Data.define classes to add builder DSL capabilities.
    #
    # @see Builders::AgentBuilder
    # @see Builders::ModelBuilder
    module Base
      # Hook called when this module is included in a class.
      #
      # Automatically extends the including class with Metadata (class methods)
      # and includes Validation, Help, and Introspection (instance methods).
      #
      # @param base [Class] The class including this module
      # @return [void]
      def self.included(base)
        base.extend(Metadata)
        base.include(Validation)
        base.include(Help)
        base.include(Support::Introspection)
      end

      # Freeze configuration to prevent further modifications.
      #
      # @return [self] Builder with frozen configuration
      # @raise [FrozenError] Raised by builder methods if frozen
      def freeze!
        with_config(__frozen__: true)
      end

      # Check if configuration is frozen.
      #
      # @return [Boolean] True if frozen
      def frozen_config? = configuration[:__frozen__] == true

      # Raise FrozenError if configuration is frozen.
      #
      # @return [void]
      # @raise [FrozenError] If frozen
      def check_frozen!
        raise FrozenError, "Cannot modify frozen #{self.class.name}" if frozen_config?
      end
    end
  end
end
