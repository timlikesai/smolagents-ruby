module Smolagents
  # DSL factory for creating custom builders with all core features.
  #
  # Wraps Ruby 4.0 Data.define and automatically includes Base module,
  # giving all builders validation, help, freeze, and pattern matching.
  #
  # @example Create a custom builder
  #   CustomBuilder = Smolagents::DSL.Builder(:target, :config) do
  #     # Register methods with validation
  #     builder_method :setting,
  #       description: "Set custom value (1-100)",
  #       validates: ->(v) { v.is_a?(Integer) && (1..100).cover?(v) },
  #       aliases: [:set]
  #
  #     # Default configuration
  #     def self.default_configuration
  #       { setting: 50, enabled: true }
  #     end
  #
  #     # Factory method
  #     def self.create(target)
  #       new(target: target, config: default_configuration)
  #     end
  #
  #     # Builder method with validation
  #     def setting(value)
  #       check_frozen!
  #       validate!(:setting, value)
  #       with_config(setting: value)
  #     end
  #     alias_method :set, :setting
  #
  #     # Build the final object
  #     def build
  #       # Your custom build logic
  #       { target: target, **config }
  #     end
  #
  #     private
  #
  #     def with_config(**kwargs)
  #       self.class.new(target: target, config: config.merge(kwargs))
  #     end
  #   end
  #
  # @example Using the custom builder
  #   builder = CustomBuilder.create(:my_target)
  #   builder.help                  # ✅ Shows all methods
  #   builder.setting(75)           # ✅ Validates range
  #   builder.setting(150)          # ❌ ArgumentError: Invalid value
  #   frozen = builder.freeze!      # ✅ Production-safe
  #   frozen.setting(50)            # ❌ FrozenError
  #
  #   # Pattern matching works automatically
  #   case builder
  #   in CustomBuilder[target: :my_target, config: { setting: }]
  #     puts "Setting: #{setting}"
  #   end
  #
  module DSL
    # Generic immutable builder factory with all core features.
    #
    # Automatically includes:
    # - Validation framework (validate!, check_frozen!)
    # - Help system (.help for REPL introspection)
    # - Immutability controls (.freeze!)
    # - Pattern matching (via Data.define)
    #
    # @param attributes [Array<Symbol>] Data.define attributes
    # @yield Block for builder implementation
    # @return [Class] Builder class with Base included
    #
    # @example Minimal builder
    #   SimpleBuilder = DSL.Builder(:value) do
    #     def self.create(value)
    #       new(value: value)
    #     end
    #
    #     def build
    #       value
    #     end
    #   end
    #
    # @example Builder with validation
    #   ValidatedBuilder = DSL.Builder(:config) do
    #     builder_method :max_retries,
    #       description: "Set max retry attempts (1-10)",
    #       validates: ->(v) { v.is_a?(Integer) && (1..10).cover?(v) }
    #
    #     def max_retries(n)
    #       validate!(:max_retries, n)
    #       check_frozen!
    #       self.class.new(config: config.merge(max_retries: n))
    #     end
    #   end
    #
    def self.Builder(*attributes, &block)
      Data.define(*attributes) do
        # Include Base first so builder_method is available
        include Builders::Base

        # Then evaluate the user's block in the class context
        class_eval(&block) if block
      end
    end
  end
end
