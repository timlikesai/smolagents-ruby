module Smolagents
  module Routing
    # Registry for routing strategies.
    #
    # Provides discovery and instantiation of routing strategies by name.
    # Built-in strategies are registered automatically.
    #
    # @example Using the registry
    #   strategy = StrategyRegistry.build(:threshold, high_threshold: 0.9)
    #   StrategyRegistry.all  # => [:threshold, :cost_aware, :composite]
    #
    # @example Registering a custom strategy
    #   class MyStrategy
    #     include RoutingStrategy
    #     def self.strategy_name = :my_strategy
    #     def route(prediction, context) = :execute_directly
    #   end
    #
    #   StrategyRegistry.register(:my_strategy, MyStrategy)
    #
    module StrategyRegistry
      @strategies = {}

      class << self
        # Registers a strategy class.
        #
        # @param name [Symbol] Strategy name
        # @param strategy_class [Class] Class implementing RoutingStrategy
        # @return [Class] The registered class
        def register(name, strategy_class) = @strategies[name.to_sym] = strategy_class

        # Returns a registered strategy class.
        #
        # @param name [Symbol] Strategy name
        # @return [Class, nil] Strategy class or nil
        def get(name) = @strategies[name.to_sym]

        # Builds a strategy instance by name.
        #
        # @param name [Symbol] Strategy name
        # @param options [Hash] Constructor options
        # @return [Object] Strategy instance
        # @raise [ArgumentError] If strategy is unknown
        def build(name, **)
          klass = get(name)
          raise ArgumentError, "Unknown strategy: #{name}" unless klass

          klass.new(**)
        end

        # Returns all registered strategy names.
        #
        # @return [Array<Symbol>]
        def all = @strategies.keys

        # Clears all registrations (for testing).
        def reset!
          @strategies = {}
          register_built_ins
        end

        # Registers built-in strategies.
        def register_built_ins
          register :threshold, Strategies::Threshold
          register :cost_aware, Strategies::CostAware
          register :composite, Strategies::Composite
        end
      end

      # Register built-in strategies on load
      register_built_ins
    end
  end
end
