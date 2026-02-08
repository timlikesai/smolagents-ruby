module Smolagents
  module Routing
    module Strategies
      # Cost-aware routing strategy considering token budget.
      #
      # Factors in remaining token budget when making routing decisions.
      # Delegates to primary model when over budget, otherwise falls
      # back to threshold-based decisions.
      #
      # @example With token budget
      #   strategy = CostAware.new
      #   context = { remaining_budget: 500, estimated_cost: 100 }
      #   decision = strategy.route(prediction, context)
      #
      # @example Over budget - delegates immediately
      #   context = { remaining_budget: 50, estimated_cost: 200 }
      #   strategy.route(prediction, context)  # => :delegate_to_primary
      #
      class CostAware
        include RoutingStrategy

        def self.strategy_name = :cost_aware

        attr_reader :fallback_strategy

        # @param fallback_strategy [RoutingStrategy] Strategy when budget is OK (default Threshold)
        def initialize(fallback_strategy: nil)
          @fallback_strategy = fallback_strategy || Threshold.new
        end

        # Routes based on budget constraints, falling back to threshold strategy.
        #
        # @param prediction [SpeculativeToolCall] The tool call to route
        # @param context [Hash] Routing context with :remaining_budget, :estimated_cost
        # @return [Symbol] :execute_directly, :validate_with_primary, or :delegate_to_primary
        def route(prediction, context)
          budget = context[:remaining_budget]
          estimated_cost = context[:estimated_cost] || estimate_cost(prediction)

          return :delegate_to_primary if over_budget?(budget, estimated_cost)

          fallback_strategy.route(prediction, context)
        end

        # Returns true if budget information is available.
        #
        # @param context [Hash] Routing context
        # @return [Boolean]
        def applicable?(context) = context.key?(:remaining_budget)

        private

        def over_budget?(budget, estimated_cost) = budget && estimated_cost && estimated_cost > budget

        def estimate_cost(prediction)
          # Rough estimate: 100 tokens for simple tool, 200 for complex
          prediction.arguments.size > 2 ? 200 : 100
        end
      end
    end
  end
end
