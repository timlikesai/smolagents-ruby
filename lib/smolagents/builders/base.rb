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
    # This module is meant to be included in Data.define classes to add
    # builder DSL capabilities. It provides the ClassMethods module for
    # registering builder methods with metadata, and instance methods for
    # validation, help text generation, and configuration freezing.
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
    # @see Builders::AgentBuilder
    # @see Builders::ModelBuilder
    # @see Builders::TeamBuilder
    module Base
      # DSL for defining builder methods with validation and documentation.
      #
      # Provides class-level macros for registering builder methods with metadata.
      # This metadata is used to generate help text, validate inputs, and document
      # the builder interface for users and AI agents.
      #
      # @example Registering a validated builder method
      #   class MyBuilder
      #     extend Base::ClassMethods
      #     register_method :max_steps,
      #       description: "Set maximum execution steps (1-1000)",
      #       required: true,
      #       validates: ->(val) { val.positive? && val <= 1000 },
      #       aliases: [:steps]
      #   end
      module ClassMethods
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
        #
        # @example Define a validated builder method
        #   register_method :max_steps,
        #     description: "Set maximum execution steps (1-1000)",
        #     required: true,
        #     validates: ->(val) { val.is_a?(Integer) && val.positive? && val <= 1000 },
        #     aliases: [:steps, :max]
        #
        # @example Define an optional method
        #   register_method :timeout,
        #     description: "Set request timeout in seconds",
        #     validates: ->(v) { v.is_a?(Numeric) && v.positive? }
        #
        # @see #registered_methods Get all registered methods
        # @see #required_methods Get only required methods
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
        #   AgentBuilder.registered_methods
        #   # => { :model => { description: "...", required: true }, :tools => { ... } }
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
        #   AgentBuilder.required_methods
        #   # => [:model, :tools]
        def required_methods
          registered_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }.keys
        end
      end

      # Hook called when this module is included in a class.
      #
      # Automatically extends the including class with ClassMethods so that
      # the register_method macro is available at the class level.
      #
      # @param base [Class] The class including this module
      # @return [void]
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Show help for this builder (REPL-friendly introspection).
      #
      # Prints a formatted help message showing all available builder methods,
      # which ones are required vs optional, their descriptions, and current
      # configuration state. Useful for exploring builder APIs interactively.
      #
      # @return [String] Formatted help text showing methods and current state
      #
      # @example Getting help
      #   agent_builder = Smolagents.agent.with(:code)
      #   puts agent_builder.help
      #   # => Shows:
      #   #    - All available methods
      #   #    - Required vs optional separation
      #   #    - Method aliases
      #   #    - Current configuration state
      #   #    - Pattern matching examples
      #
      # @see #frozen_config? Check if configuration is frozen
      # @see #freeze! Prevent further modifications
      def help
        parts = [
          "\n#{self.class.name} - Available Methods\n",
          ("=" * 60)
        ]

        parts.concat(help_methods_section)
        parts.concat(help_footer_section)

        parts.join("\n")
      end

      # Freeze this builder's configuration, preventing further modifications.
      #
      # Returns a builder with a special :__frozen__ marker in configuration.
      # Useful for production configurations that should be immutable and prevent
      # accidental modifications. After freezing, any attempt to call a builder method
      # will raise FrozenError.
      #
      # @return [self] Builder with frozen configuration
      #
      # @raise [FrozenError] Raised by any builder method if configuration is frozen
      #
      # @example Freeze a production configuration
      #   PRODUCTION_MODEL = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .api_key(ENV["OPENAI_API_KEY"])
      #     .freeze!
      #
      #   # Later attempts to modify raise FrozenError
      #   PRODUCTION_MODEL.temperature(0.5)  # => FrozenError: Cannot modify frozen ModelBuilder
      #
      # @see #frozen_config? Check if frozen
      # @see #check_frozen! Helper to validate frozen state
      def freeze!
        with_config(__frozen__: true)
      end

      # Check if this builder's configuration is frozen.
      #
      # Returns true if this builder was frozen with {#freeze!}, which prevents
      # any further modifications via builder methods.
      #
      # @return [Boolean] True if configuration is frozen, false otherwise
      #
      # @example Checking frozen state
      #   builder = Smolagents.model(:openai).id("gpt-4")
      #   builder.frozen_config?  # => false
      #   builder.freeze!.frozen_config?  # => true
      #
      # @see #freeze! Prevent further modifications
      # @see #check_frozen! Helper that raises if frozen
      def frozen_config? = configuration[:__frozen__] == true

      # Validate a value against registered validation rules.
      #
      # Looks up the validation block for the given method name and runs the
      # validator against the value. Raises ArgumentError with a helpful message
      # if validation fails. Does nothing if no validator is registered.
      #
      # @param method_name [Symbol] Method being called (must be registered with register_method)
      # @param value [Object] Value to validate
      #
      # @return [void]
      #
      # @raise [ArgumentError] If validation block returns false, includes method description
      #
      # @example Validating within a builder method
      #   def max_steps(n)
      #     check_frozen!
      #     validate!(:max_steps, n)  # Raises ArgumentError if invalid
      #     with_config(max_steps: n)
      #   end
      #
      # @see #validate_required! Validate all required methods are called
      # @see Builders::Base::ClassMethods#register_method Define validators
      def validate!(method_name, value)
        return unless self.class.registered_methods[method_name]

        validator = self.class.registered_methods[method_name][:validates]
        return unless validator

        return if validator.call(value)

        description = self.class.registered_methods[method_name][:description]
        raise ArgumentError, "Invalid value for #{method_name}: #{value.inspect}. #{description}"
      end

      # Validate that all required methods have been called.
      #
      # Checks that every method registered with register_method(required: true)
      # has been set in the configuration. Useful to call before {#build} to ensure
      # all mandatory configuration is present.
      #
      # @return [void]
      #
      # @raise [ArgumentError] If required methods are missing, lists missing methods
      #
      # @example Validating before building
      #   def build
      #     validate_required!  # Raises if model is missing
      #     # ... build agent ...
      #   end
      #
      # @see Builders::Base::ClassMethods#register_method Mark methods as required
      def validate_required!
        missing = self.class.required_methods.reject { |method| configuration.key?(method) }
        return if missing.empty?

        raise ArgumentError, "Missing required configuration: #{missing.join(", ")}. Use .help for details."
      end

      # Check if builder configuration is frozen before modification.
      #
      # Raises FrozenError if this builder's configuration is frozen. Called by
      # builder methods to prevent modification of frozen configurations. This
      # allows treating production configurations as immutable.
      #
      # @return [void]
      #
      # @raise [FrozenError] If configuration is frozen (set via {#freeze!})
      #
      # @example Using in a builder method
      #   def model(&block)
      #     check_frozen!  # Prevent modifying frozen config
      #     with_config(model_block: block)
      #   end
      #
      # @see #freeze! Prevent further modifications
      # @see #frozen_config? Check frozen state
      def check_frozen!
        raise FrozenError, "Cannot modify frozen #{self.class.name}" if frozen_config?
      end

      private

      # Generate methods section of help output.
      #
      # Creates formatted help text for all registered builder methods,
      # separated into Required and Optional sections. Includes method names,
      # descriptions, and aliases.
      #
      # @return [Array<String>] Help text lines for methods section
      #
      # @api private
      def help_methods_section
        parts = []
        parts.concat(format_method_group("Required", required_registered_methods)) if required_registered_methods.any?
        parts.concat(format_method_group("Optional", optional_registered_methods)) if optional_registered_methods.any?
        parts
      end

      def required_registered_methods
        self.class.registered_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }
      end

      def optional_registered_methods
        self.class.registered_methods.reject { |_, meta| meta[:required] || meta[:alias_of] }
      end

      # Format a group of methods (required or optional).
      #
      # Takes a labeled group of methods and formats them into human-readable
      # help text with descriptions and aliases.
      #
      # @param label [String] Group label (e.g., "Required" or "Optional")
      # @param methods [Hash<Symbol, Hash>] Methods to format from {#registered_methods}
      #
      # @return [Array<String>] Formatted lines of help text
      #
      # @api private
      def format_method_group(label, methods)
        lines = ["\n#{label}:"]
        methods.each do |name, meta|
          aliases_str = meta[:aliases].any? ? " (aliases: #{meta[:aliases].join(", ")})" : ""
          lines << "  .#{name}#{aliases_str}"
          lines << "    #{meta[:description]}"
        end
        lines
      end

      # Generate footer section of help output.
      #
      # Creates the footer section of help text including current configuration,
      # pattern matching examples, and build instructions.
      #
      # @return [Array<String>] Help text lines for footer section
      #
      # @api private
      def help_footer_section
        [
          "\nCurrent Configuration:", "  #{inspect}",
          "\nPattern Matching:", "  case builder",
          "  in #{self.class.name}[#{data_define_attributes}]", "    # Match and destructure", "  end",
          "\nBuild:", "  .build - Create the configured object", ""
        ]
      end

      # Get Data.define attributes for pattern matching help.
      #
      # Extracts the member names from this builder's Data.define class
      # to show in pattern matching help examples.
      #
      # @return [String] Comma-separated attribute pattern or "..." if not found
      #
      # @api private
      def data_define_attributes
        self.class.ancestors.find { |a| a.is_a?(Class) && a.superclass == Data }
            &.members&.join(", ") || "..."
      end
    end
  end
end
