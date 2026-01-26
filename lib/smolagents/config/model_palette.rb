module Smolagents
  module Config
    # Registry for named model factories.
    #
    # ModelPalette provides a simple registry for storing and retrieving model
    # factory callables by name. This enables declarative model configuration
    # where models can be registered once and instantiated on demand.
    #
    # @example Registering and using models
    #   palette = ModelPalette.create
    #     .register(:gpt4, -> { OpenAIModel.new("gpt-4") })
    #     .register(:claude, -> { AnthropicModel.new("claude-3") })
    #
    #   model = palette.get(:gpt4)  # Creates new instance
    #
    # @example Checking registration
    #   palette.registered?(:gpt4)  # => true
    #   palette.names               # => [:gpt4, :claude]
    #
    # @see Models::Model Base class for model implementations
    ModelPalette = Data.define(:registry) do
      # Creates an empty model palette.
      #
      # @return [ModelPalette] New palette with empty registry
      def self.create = new(registry: {}.freeze)

      # Registers a model factory under the given name.
      #
      # @param name [Symbol, String] Name to register the factory under
      # @param factory [#call] Callable that returns a model instance
      # @return [ModelPalette] New palette with the factory registered
      # @raise [ArgumentError] If factory is not callable
      #
      # @example Registering a model
      #   palette = palette.register(:fast, -> { OpenAIModel.new("gpt-3.5-turbo") })
      def register(name, factory)
        raise ArgumentError, "Factory must be callable" unless factory.respond_to?(:call)

        with(registry: registry.merge(name.to_sym => factory).freeze)
      end

      # Retrieves and instantiates a model by name.
      #
      # @param name [Symbol, String] Name of the registered model
      # @return [Model] New model instance from the factory
      # @raise [ArgumentError] If no model is registered under the given name
      #
      # @example Getting a model
      #   model = palette.get(:gpt4)
      def get(name)
        factory = registry[name.to_sym]
        raise ArgumentError, "Model not registered: #{name}. Available: #{names.join(", ")}" unless factory

        factory.call
      end

      # Checks if a model is registered under the given name.
      #
      # @param name [Symbol, String] Name to check
      # @return [Boolean] True if a factory is registered under that name
      def registered?(name) = registry.key?(name.to_sym)

      # Returns all registered model names.
      #
      # @return [Array<Symbol>] List of registered model names
      def names = registry.keys
    end
  end
end
