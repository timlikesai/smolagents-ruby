module Smolagents
  module Concerns
    # Token budget tracking and enforcement across agent hierarchy.
    #
    # Tracks cumulative token usage and raises TokenBudgetExceeded
    # when the configured budget is exhausted. Parent agents can
    # allocate token budgets to children via SpawnContext.
    #
    # @example
    #   agent = Smolagents.agent.model { m }.token_budget(50_000).build
    #   agent.run("task")  # raises TokenBudgetExceeded if budget exceeded
    module CostAccounting
      # @return [Integer, nil] Configured token budget (nil = unlimited)
      attr_reader :token_budget

      # @return [Integer] Tokens consumed so far
      attr_reader :tokens_consumed

      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
      end

      # Initialize cost accounting.
      # @param budget [Integer, nil] Token budget (nil = unlimited)
      def initialize_cost_accounting(budget: nil)
        @token_budget = budget
        @tokens_consumed = 0
      end

      # Consume tokens from the budget.
      # @param usage [#total_tokens, Hash, Integer, nil] Token usage to record
      # @return [void]
      def consume_tokens(usage)
        return unless usage

        amount = case usage
                 when Integer then usage
                 when Hash then usage[:total_tokens] || 0
                 else usage.respond_to?(:total_tokens) ? usage.total_tokens : 0
                 end
        @tokens_consumed = (@tokens_consumed || 0) + amount
      end

      # Remaining token budget.
      # @return [Integer, nil] Remaining tokens, or nil if unlimited
      def remaining_token_budget
        return nil unless @token_budget

        [@token_budget - (@tokens_consumed || 0), 0].max
      end

      # Check if budget is exceeded.
      # @return [Boolean]
      def token_budget_exceeded?
        return false unless @token_budget

        (@tokens_consumed || 0) >= @token_budget
      end

      # Check and raise if budget exceeded.
      # @raise [Errors::TokenBudgetExceeded] If over budget
      def check_token_budget!
        return unless token_budget_exceeded?

        raise Errors::TokenBudgetExceeded.new(
          "Token budget exceeded: #{@tokens_consumed}/#{@token_budget}",
          budget: @token_budget, consumed: @tokens_consumed
        )
      end
    end
  end
end
