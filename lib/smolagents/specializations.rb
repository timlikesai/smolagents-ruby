module Smolagents
  # Registry for agent specializations.
  #
  # Specializations bundle tools and personas into named configurations.
  # All agents think in Ruby code - specializations just configure WHAT
  # tools are available and HOW the agent should approach tasks.
  #
  # == Architecture
  #
  # - *Tools* - WHAT the agent can do (capabilities)
  # - *Personas* - HOW the agent approaches tasks (behavioral instructions)
  # - *Specializations* - Named bundles of tools + persona
  #
  # == Built-in Specializations
  #
  # :data_analyst, :researcher, :fact_checker, :calculator, :web_scraper
  #
  # @example Using a specialization
  #   agent = Smolagents.agent.model { ... }.with(:researcher).build
  #
  # @example List available specializations
  #   Smolagents::Specializations.names  #=> [:data_analyst, :researcher, ...]
  #
  # @see Personas Behavioral instructions
  # @see Tools::REGISTRY Available tools
  module Specializations
    @registry = {}

    class << self
      # Defines a new specialization.
      #
      # @param name [Symbol] Unique identifier
      # @param tools [Array<Symbol>] Tool names to include
      # @param instructions [String, nil] Persona instructions
      # @return [Types::Specialization] The registered specialization
      def define(name, tools: [], instructions: nil)
        spec = Types::Specialization.create(name, tools:, instructions:)
        @registry[name.to_sym] = spec
        define_singleton_method(name) { @registry[name.to_sym] }
        spec
      end

      # Alias for define.
      def register(name, tools: [], instructions: nil)
        define(name, tools:, instructions:)
      end

      # Looks up a specialization by name.
      # @return [Types::Specialization, nil]
      def get(name) = @registry[name.to_sym]

      # Returns all registered specialization names.
      # @return [Array<Symbol>]
      def names = @registry.keys

      # Returns all registered specializations.
      # @return [Array<Types::Specialization>]
      def all = @registry.values
    end

    # Load built-in specializations
    require_relative "specializations/built_in"
    BuiltIn.register_all(self)
  end
end
