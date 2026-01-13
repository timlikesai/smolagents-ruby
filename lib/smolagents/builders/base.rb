module Smolagents
  module Builders
    # Core builder functionality shared across all builders.
    #
    # Provides:
    # - Validation framework with helpful error messages
    # - Introspection via .help() for REPL-friendly development
    # - Immutability controls via .freeze! for production safety
    # - Standard callback patterns
    # - Pattern matching support (via Data.define)
    #
    # @example Using builder help
    #   builder = Smolagents.model(:openai)
    #   builder.help
    #   # => Shows all available methods, required vs optional, current state
    #
    # @example Freezing configuration
    #   config = Smolagents.model(:openai)
    #     .id("gpt-4")
    #     .api_key(ENV["KEY"])
    #     .freeze!
    #   # Any further modifications raise FrozenError
    #
    module Base
      # DSL for defining builder methods with validation and documentation
      module ClassMethods
        # Register a builder method with metadata for help/validation
        #
        # @param name [Symbol] Method name
        # @param description [String] Human-readable description
        # @param required [Boolean] Whether this method must be called before build
        # @param validates [Proc, nil] Optional validation block
        # @param aliases [Array<Symbol>] Method aliases
        #
        # @example Define a validated builder method
        #   builder_method :max_steps,
        #     description: "Set maximum execution steps (1-1000)",
        #     validates: ->(val) { val.positive? && val <= 1000 },
        #     aliases: [:steps]
        #
        def builder_method(name, description:, required: false, validates: nil, aliases: [])
          @builder_methods ||= {}
          @builder_methods[name] = {
            description: description,
            required: required,
            validates: validates,
            aliases: aliases
          }

          # Register aliases
          aliases.each do |alias_name|
            @builder_methods[alias_name] = @builder_methods[name].merge(alias_of: name)
          end
        end

        # Get all registered builder methods
        #
        # @return [Hash] Method metadata
        def builder_methods
          @builder_methods ||= {}
        end

        # Get required method names
        #
        # @return [Array<Symbol>] Required method names
        def required_methods
          builder_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }.keys
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      # Show help for this builder (REPL-friendly introspection)
      #
      # @return [String] Formatted help text
      def help
        parts = [
          "\n#{self.class.name} - Available Methods\n",
          ("=" * 60)
        ]

        parts.concat(help_methods_section)
        parts.concat(help_footer_section)

        parts.join("\n")
      end

      # Freeze this builder's configuration, preventing further modifications
      #
      # Returns a builder with a special :__frozen__ marker in configuration.
      # Useful for production configurations that should be immutable.
      #
      # @return [self] Builder with frozen configuration
      #
      # @example Freeze a production configuration
      #   PRODUCTION_MODEL = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .api_key(ENV["OPENAI_API_KEY"])
      #     .freeze!
      #
      #   # Later attempts to modify raise FrozenError
      #   PRODUCTION_MODEL.temperature(0.5)  # => FrozenError
      #
      def freeze!
        with_config(__frozen__: true)
      end

      # Check if this builder's configuration is frozen
      #
      # @return [Boolean] True if configuration is frozen
      def frozen_config?
        configuration[:__frozen__] == true
      end

      # Validate a value against registered validation rules
      #
      # @param method_name [Symbol] Method being called
      # @param value [Object] Value to validate
      # @raise [ArgumentError] If validation fails
      #
      def validate!(method_name, value)
        return unless self.class.builder_methods[method_name]

        validator = self.class.builder_methods[method_name][:validates]
        return unless validator

        return if validator.call(value)

        description = self.class.builder_methods[method_name][:description]
        raise ArgumentError, "Invalid value for #{method_name}: #{value.inspect}. #{description}"
      end

      # Validate that all required methods have been called
      #
      # @raise [ArgumentError] If required methods are missing
      def validate_required!
        missing = self.class.required_methods.reject { |method| configuration.key?(method) }
        return if missing.empty?

        raise ArgumentError, "Missing required configuration: #{missing.join(", ")}. Use .help for details."
      end

      # Check if builder configuration is frozen before modification
      #
      # @raise [FrozenError] If configuration is frozen
      def check_frozen!
        raise FrozenError, "Cannot modify frozen #{self.class.name}" if frozen_config?
      end

      private

      # Generate methods section of help output
      #
      # @return [Array<String>] Help text lines for methods
      def help_methods_section
        required = self.class.builder_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }
        optional = self.class.builder_methods.reject { |_, meta| meta[:required] || meta[:alias_of] }

        parts = []
        parts.concat(format_method_group("Required", required)) if required.any?
        parts.concat(format_method_group("Optional", optional)) if optional.any?
        parts
      end

      # Format a group of methods (required or optional)
      #
      # @param label [String] Group label
      # @param methods [Hash] Methods to format
      # @return [Array<String>] Formatted lines
      def format_method_group(label, methods)
        lines = ["\n#{label}:"]
        methods.each do |name, meta|
          aliases_str = meta[:aliases].any? ? " (aliases: #{meta[:aliases].join(", ")})" : ""
          lines << "  .#{name}#{aliases_str}"
          lines << "    #{meta[:description]}"
        end
        lines
      end

      # Generate footer section of help output
      #
      # @return [Array<String>] Help text lines for footer
      def help_footer_section
        [
          "\nCurrent Configuration:",
          "  #{inspect}",
          "\nPattern Matching:",
          "  case builder",
          "  in #{self.class.name}[#{data_define_attributes}]",
          "    # Match and destructure",
          "  end",
          "\nBuild:",
          "  .build - Create the configured object",
          ""
        ]
      end

      # Get Data.define attributes for pattern matching help
      #
      # @return [String] Attribute pattern
      def data_define_attributes
        self.class.ancestors.find { |a| a.is_a?(Class) && a.superclass == Data }
            &.members&.join(", ") || "..."
      end
    end
  end
end
