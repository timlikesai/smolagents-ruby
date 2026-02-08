# Metrics from context assembly process.
#
# Captures budget allocations, actual contributions, and provider
# inclusion/exclusion decisions during context assembly.
#
# @example Accessing metrics
#   metrics = orchestrator.assemble(task: "search", step: 1).metrics
#   metrics.utilization_percent  #=> 75.5
#   metrics.headroom            #=> 245
module Smolagents
  module Types
    ContextAssemblyMetrics = Data.define(
      :provider_budgets,       # Hash[Symbol, Integer] - allocated budgets
      :provider_contributions, # Hash[Symbol, Integer] - actual token usage
      :total_budget,
      :total_used,
      :providers_included,     # Array[Symbol]
      :providers_excluded      # Array[Symbol]
    ) do
      # Creates empty metrics with the given total budget.
      # @param budget [Integer] Total token budget
      # @return [ContextAssemblyMetrics]
      def self.empty(budget: 0)
        new(
          provider_budgets: {},
          provider_contributions: {},
          total_budget: budget,
          total_used: 0,
          providers_included: [],
          providers_excluded: []
        )
      end

      # Returns utilization as a percentage rounded to one decimal.
      # @return [Float] Utilization percentage (0.0 to 100.0+)
      def utilization_percent
        total_budget.positive? ? (total_used.to_f / total_budget * 100).round(1) : 0.0
      end

      # Returns remaining budget.
      # @return [Integer] Tokens remaining
      def headroom = total_budget - total_used
    end
  end
end
