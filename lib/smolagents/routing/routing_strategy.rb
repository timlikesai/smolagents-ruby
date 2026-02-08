module Smolagents
  module Routing
    # Base interface for routing strategies.
    #
    # Routing strategies decide how to handle speculative tool calls:
    # - execute_directly: high confidence, run without validation
    # - validate_with_primary: medium confidence, ask primary to confirm
    # - delegate_to_primary: low confidence, let primary decide
    #
    # @example Implementing a custom strategy
    #   class MyStrategy
    #     include RoutingStrategy
    #
    #     def self.strategy_name = :my_strategy
    #
    #     def route(prediction, context)
    #       # Custom logic here
    #       :execute_directly
    #     end
    #   end
    #
    module RoutingStrategy
      # Valid routing decisions.
      DECISIONS = %i[execute_directly validate_with_primary delegate_to_primary].freeze

      def self.included(base)
        base.extend ClassMethods
      end

      # Class methods added when RoutingStrategy is included.
      module ClassMethods
        # Returns the symbolic name for this strategy.
        # @return [Symbol]
        def strategy_name = raise NotImplementedError, "#{self}.strategy_name must be implemented"
      end

      # Makes a routing decision for a speculative tool call.
      #
      # @param prediction [SpeculativeToolCall] The tool call to route
      # @param context [Hash] Routing context (tools, config, budget, etc.)
      # @return [Symbol] One of DECISIONS
      def route(prediction, context)
        raise NotImplementedError, "#{self.class}#route must be implemented"
      end

      # Checks if this strategy can handle the given context.
      #
      # @param context [Hash] Routing context
      # @return [Boolean] True if strategy is applicable
      def applicable?(_context) = true
    end
  end
end
