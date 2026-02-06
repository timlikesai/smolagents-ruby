# Context provider registry for runtime discovery.
#
# Maintains a mutable registry of context providers, allowing
# runtime registration and lookup by key or layer.
#
# @example Register a provider class
#   Registry.register(:goals, GoalProvider)
#
# @example Look up by key
#   Registry[:goals]  #=> GoalProvider
#
# @example Get all providers for a layer
#   Registry.for_layer(Layer::STRATEGIC)  #=> [GoalProvider, PlanProvider, ...]
require_relative "../types/context/layer"

module Smolagents
  module Context
    module Registry
      # rubocop:disable Style/MutableConstant -- intentionally mutable for runtime registration
      PROVIDERS = {}
      # rubocop:enable Style/MutableConstant

      class << self
        # Registers a provider class.
        # @param key [Symbol] unique provider key
        # @param klass [Class] provider class implementing Provider protocol
        # @return [Class] the registered class
        def register(key, klass)
          PROVIDERS[key] = klass
        end

        # Looks up a provider by key.
        # @param key [Symbol] provider key
        # @return [Class, nil] provider class or nil if not found
        def [](key) = PROVIDERS[key]

        # All registered provider keys.
        # @return [Array<Symbol>]
        def all = PROVIDERS.keys

        # All registered provider classes.
        # @return [Array<Class>]
        def providers = PROVIDERS.values

        # Checks if a provider is registered.
        # @param key [Symbol] provider key
        # @return [Boolean]
        def registered?(key) = PROVIDERS.key?(key)

        # Gets providers for a specific layer.
        # @param layer [Layer] the layer to filter by
        # @return [Array<Class>] provider classes for this layer
        def for_layer(layer)
          PROVIDERS.values.select do |klass|
            instance = klass.respond_to?(:new) ? klass.new : klass
            instance.context_layer == layer
          rescue ArgumentError
            false
          end
        end

        # Gets providers grouped by layer.
        # @return [Hash{Layer => Array<Class>}]
        def by_layer
          Layer::ALL.to_h { |layer| [layer, for_layer(layer)] }
        end

        # Clears all registered providers (for testing).
        # @api private
        def clear! = PROVIDERS.clear

        # Returns count of registered providers.
        # @return [Integer]
        def size = PROVIDERS.size
      end
    end
  end
end
