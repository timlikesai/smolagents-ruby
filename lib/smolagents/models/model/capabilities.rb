module Smolagents
  module Models
    class Model
      # Mixin for model capability exposure.
      #
      # Provides access to ServerCapability metadata through the Model interface,
      # with lazy initialization and convenient predicate methods.
      #
      # @example Check if model supports tools
      #   model.supports_tools?  # => true
      #
      # @example Get context window limit
      #   model.context_window  # => 128_000
      #
      # @see Types::ServerCapability
      module Capabilities
        def self.included(base)
          base.extend ClassMethods
        end

        # Class-level methods for subclass customization.
        module ClassMethods
          # Override in subclasses for provider-specific defaults.
          #
          # @return [Types::ServerCapability]
          def default_capabilities = Types::ServerCapability.unknown
        end

        # Access the capabilities for this model instance.
        #
        # Lazily initialized on first access via {#build_capabilities}.
        #
        # @return [Types::ServerCapability]
        def capabilities
          @capabilities ||= build_capabilities
        end

        # Predicate delegates - use endless methods
        def supports_tools? = capabilities.supports_tools
        def supports_vision? = capabilities.supports_vision
        def supports_json_schema? = capabilities.supports_json_schema
        def supports_json_object? = capabilities.supports_json_object

        # Context limits - use endless methods
        def capability_context_window = capabilities.max_context_length
        def capability_max_output_tokens = capabilities.max_tokens_limit

        private

        # Build the capabilities for this model instance.
        #
        # Override in subclasses for custom detection.
        #
        # @return [Types::ServerCapability]
        def build_capabilities = self.class.default_capabilities
      end
    end
  end
end
