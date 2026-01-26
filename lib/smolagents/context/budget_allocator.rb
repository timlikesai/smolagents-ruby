# Token budget allocation for context providers.
#
# Scores providers by priority × relevance and distributes
# tokens proportionally, ensuring required providers get their share.
#
# @example Basic allocation
#   allocator = BudgetAllocator.new(total_budget: 4000)
#   allocations = allocator.allocate(providers, task: "search", step: 1)
#   allocations[:goals]  #=> 800
require_relative "layer"

module Smolagents
  module Context
    class BudgetAllocator
      DEFAULT_BUDGET = 4000
      MIN_PROVIDER_BUDGET = 50

      attr_reader :total_budget

      def initialize(total_budget: DEFAULT_BUDGET)
        @total_budget = total_budget
      end

      # Allocates budget to active providers.
      # @param providers [Array<Provider>] provider instances
      # @param task [String] current task
      # @param step [Integer] current step number
      # @return [Hash{Symbol => Integer}] budget per provider key
      def allocate(providers, task:, step:)
        active = providers.select(&:context_active?)
        return {} if active.empty?

        scored = score_providers(active, task:, step:)
        distribute(scored)
      end

      # Scores a single provider.
      # @param provider [Provider] provider instance
      # @param task [String] current task
      # @param step [Integer] current step number
      # @return [Float] score (priority × relevance)
      def score(provider, task:, step:)
        priority = provider.context_priority.to_f
        relevance = provider.context_relevance(task:, step:).to_f.clamp(0.0, 1.0)
        priority * relevance
      end

      private

      def score_providers(providers, task:, step:)
        providers.map do |provider|
          { provider:, key: provider.context_key, score: score(provider, task:, step:),
            optional: provider.context_optional?, layer: provider.context_layer }
        end
      end

      def distribute(scored)
        return {} if scored.empty?

        total_score = scored.sum { |s| s[:score] }
        return equal_distribution(scored) if total_score.zero?

        allocations = allocate_required(scored, total_score)
        allocate_optional(scored, allocations)
      end

      def allocate_required(scored, total_score)
        required = scored.reject { |s| s[:optional] }
        remaining = @total_budget - (required.size * MIN_PROVIDER_BUDGET)

        required.to_h do |entry|
          share = (entry[:score] / total_score * [remaining, 0].max).round
          [entry[:key], [share + MIN_PROVIDER_BUDGET, MIN_PROVIDER_BUDGET].max]
        end
      end

      def allocate_optional(scored, allocations)
        optional = scored.select { |s| s[:optional] }
        available = [@total_budget - allocations.values.sum, 0].max
        optional.each { |entry| add_optional_allocation(entry, optional, available, allocations) }
        allocations
      end

      def add_optional_allocation(entry, optional, available, allocations)
        total = optional.sum { |s| s[:score] }
        share = total.positive? ? (entry[:score] / total * available).round : 0
        allocations[entry[:key]] = [share, MIN_PROVIDER_BUDGET].max if share >= MIN_PROVIDER_BUDGET
      end

      def equal_distribution(scored)
        budget_each = @total_budget / scored.size
        scored.to_h { |s| [s[:key], budget_each] }
      end
    end
  end
end
