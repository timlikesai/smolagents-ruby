module Smolagents
  module Builders
    module Base
      # DSL for defining builder methods with validation and documentation.
      #
      # Provides class-level macros for registering builder methods with metadata.
      # This metadata is used to generate help text, validate inputs, and document
      # the builder interface for users and AI agents.
      #
      # @example Registering a method
      #   register_method :temperature,
      #     description: "Set temperature (0.0-2.0)",
      #     required: false,
      #     validates: ->(v) { v.is_a?(Numeric) && v.between?(0.0, 2.0) },
      #     aliases: [:temp]
      #
      # @api private
      module Metadata
        # Register a builder method with metadata for help/validation.
        #
        # This macro stores metadata about builder methods (like description, whether
        # they're required, validation rules, and aliases) so that the builder can
        # provide intelligent help text and validate configuration before building.
        #
        # @param name [Symbol] Method name to register
        # @param description [String] Human-readable description of what this method does
        # @param required [Boolean] Whether this method must be called before build. Default: false
        # @param validates [Proc, nil] Optional validation block taking the value and returning true/false
        # @param aliases [Array<Symbol>] Alternative method names. Default: []
        #
        # @return [void]
        #
        # @raise [ArgumentError] Raised by validate! if validation block returns false
        # @api private
        def register_method(name, description:, required: false, validates: nil, aliases: [])
          @registered_methods ||= {}
          @registered_methods[name] = {
            description:,
            required:,
            validates:,
            aliases:
          }

          # Register aliases
          aliases.each do |alias_name|
            @registered_methods[alias_name] = @registered_methods[name].merge(alias_of: name)
          end
        end

        # Get all registered builder methods.
        #
        # Returns a hash of all methods registered with {#register_method}, indexed
        # by method name. Each entry contains metadata like description, whether it's
        # required, validation rules, and aliases.
        #
        # @return [Hash<Symbol, Hash>] Method metadata indexed by name. Each hash contains:
        #   - :description [String] Description of what the method does
        #   - :required [Boolean] Whether method must be called before build
        #   - :validates [Proc, nil] Optional validation block
        #   - :aliases [Array<Symbol>] Alternative method names
        #   - :alias_of [Symbol, nil] If this is an alias, the original method name
        #
        # @example Inspecting registered methods
        #   Smolagents::Builders::AgentBuilder.registered_methods.key?(:model)
        #   #=> true
        def registered_methods
          @registered_methods ||= {}
        end

        # Get required method names.
        #
        # Returns an array of method names that must be called before {#build}
        # is invoked. Aliases are excluded since they're variants of required methods.
        #
        # @return [Array<Symbol>] Required method names (excluding aliases)
        #
        # @example Finding required methods
        #   Smolagents::Builders::AgentBuilder.required_methods.include?(:model)
        #   #=> true
        def required_methods
          registered_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }.keys
        end
      end
    end
  end
end
