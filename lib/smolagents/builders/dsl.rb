module Smolagents
  # DSL factory for creating custom builders with all core features.
  #
  # Wraps Ruby 4.0 Data.define and automatically includes the Base module,
  # giving all builders validation, help, freeze, and pattern matching support.
  #
  # == Features Included Automatically
  #
  # - **Validation**: Use +validate!+ and +register_method+ for input validation
  # - **Help**: Call +.help+ for REPL-friendly introspection
  # - **Freeze**: Call +.freeze!+ for production-safe immutability
  # - **Pattern matching**: Works automatically via Data.define
  #
  # @see Builders::Base For the included functionality
  module DSL
    # Generic immutable builder factory with all core features.
    #
    # Creates a Data.define class with the Base module automatically included.
    # The block is evaluated in the class context, giving access to:
    # - +register_method+ for method registration with validation
    # - +validate!+ for validating values
    # - +check_frozen!+ for preventing frozen modifications
    #
    # @param attributes [Array<Symbol>] Data.define attributes for the builder
    # @yield Block evaluated in the class context for builder implementation
    # @return [Class] Builder class with Base included
    #
    # @example Creating a simple builder
    #   SimpleBuilder = Smolagents::DSL.Builder(:value) do
    #     def self.create(value)
    #       new(value: value)
    #     end
    #
    #     def build = value
    #   end
    #   builder = SimpleBuilder.create(42)
    #   builder.value
    #   #=> 42
    #
    # @example Builder with configuration
    #   ConfigBuilder = Smolagents::DSL.Builder(:configuration) do
    #     def self.create
    #       new(configuration: { limit: 10 })
    #     end
    #
    #     def limit(n)
    #       self.class.new(configuration: configuration.merge(limit: n))
    #     end
    #   end
    #   builder = ConfigBuilder.create.limit(50)
    #   builder.configuration[:limit]
    #   #=> 50
    def self.Builder(*attributes, &block)
      Data.define(*attributes) do
        # Include Base first so register_method is available
        include Builders::Base

        # Then evaluate the user's block in the class context
        class_eval(&block) if block
      end
    end
  end
end
