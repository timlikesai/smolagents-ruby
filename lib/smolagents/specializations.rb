module Smolagents
  # Registry for convenience agent specializations.
  #
  # Specializations are convenience bundles that combine tools, instructions,
  # and mode requirements into a single named entity. Use them with `.with(:name)`.
  #
  # == Key Distinction
  #
  # - *Toolkits* add tools only (what the agent can use)
  # - *Personas* add instructions only (how the agent behaves)
  # - *Specializations* add both (convenience bundles)
  #
  # == Built-in Specializations
  #
  # :code, :data_analyst, :researcher, :fact_checker, :calculator, :web_scraper
  #
  # @example List all available specialization names
  #   Smolagents::Specializations.names.include?(:researcher)  #=> true
  #   Smolagents::Specializations.names.include?(:data_analyst)  #=> true
  #
  # @example Look up a specialization
  #   spec = Smolagents::Specializations.get(:researcher)
  #   spec.nil?  #=> false
  #
  # @example Unknown specialization returns nil
  #   Smolagents::Specializations.get(:unknown)  #=> nil
  #
  # @see Toolkits Tool groupings (what the agent can use)
  # @see Personas Behavioral instructions (how the agent behaves)
  # @see Builders::AgentBuilder#with The DSL method for using specializations
  # @see Smolagents.specialization Registering custom specializations
  module Specializations
    @registry = {}

    class << self
      # Defines a new specialization using the declarative pattern.
      #
      # @param name [Symbol] Unique identifier for the specialization
      # @param tools [Array<Symbol>] Tool names to include
      # @param instructions [String, nil] Instructions to add to system prompt
      # @param requires [Symbol, nil] Capability requirement (:code)
      # @return [Types::Specialization] The registered specialization
      #
      # @example Define a basic specialization
      #   Smolagents::Specializations.define(:my_spec, tools: [:search])
      #   Smolagents::Specializations.names.include?(:my_spec)  #=> true
      def define(name, tools: [], instructions: nil, requires: nil)
        spec = Types::Specialization.create(name, tools:, instructions:, requires:)
        @registry[name.to_sym] = spec
        define_singleton_method(name) { @registry[name.to_sym] }
        spec
      end

      # Registers a new specialization (alias for define).
      #
      # @see #define
      def register(name, tools: [], instructions: nil, requires: nil)
        define(name, tools:, instructions:, requires:)
      end

      # Looks up a specialization by name.
      #
      # @param name [Symbol, String] Specialization name
      # @return [Types::Specialization, nil]
      def get(name) = @registry[name.to_sym]

      # Returns all registered specialization names.
      #
      # @return [Array<Symbol>]
      def names = @registry.keys

      # Returns all registered specializations.
      #
      # @return [Array<Types::Specialization>]
      def all = @registry.values
    end

    # Load built-in specializations
    require_relative "specializations/built_in"
    BuiltIn.register_all(self)
  end
end
