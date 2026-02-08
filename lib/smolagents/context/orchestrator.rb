# Context orchestrator for agent message assembly.
#
# Queries registered providers, allocates budgets, and builds
# layered context for model consumption.
#
# @example Basic usage
#   orchestrator = Orchestrator.new(providers: [goal_provider, plan_provider])
#   result = orchestrator.assemble(task: "Find info", step: 1)
#   result.content  #=> "# == Goal ==\n# Find info\n..."
#   result.metrics.utilization_percent  #=> 75.5
require_relative "../types/context/layer"
require_relative "../types/context_assembly_metrics"
require_relative "budget_allocator"
require_relative "ruby_presenter"
require_relative "token_meter"

module Smolagents
  module Context
    # Result of context assembly.
    AssemblyResult = Data.define(:content, :layers, :metadata, :metrics) do
      def to_s = content

      def layer_content(layer) = layers[layer.name]
    end

    class Orchestrator
      # Characters per token for estimation.
      CHARS_PER_TOKEN = 4

      attr_reader :providers, :allocator

      def initialize(providers: [], total_budget: BudgetAllocator::DEFAULT_BUDGET)
        @providers = providers
        @allocator = BudgetAllocator.new(total_budget:)
      end

      # Assembles context from all active providers.
      # @param task [String] current task
      # @param step [Integer] current step number
      # @return [AssemblyResult] assembled context
      def assemble(task:, step:)
        budgets = @allocator.allocate(@providers, task:, step:)
        meter = TokenMeter.new(budget: @allocator.total_budget)
        contributions, meter, excluded = collect_contributions_with_metrics(budgets, meter)
        layered = organize_by_layer(contributions)
        content = format_layers(layered)

        layers = layer_content_map(layered)
        metadata = build_metadata(contributions, budgets)
        metrics = build_metrics(contributions, budgets, meter, excluded)
        AssemblyResult.new(content:, layers:, metadata:, metrics:)
      end

      # Adds a provider to the orchestrator.
      # @param provider [Provider] provider instance
      # @return [self]
      def add_provider(provider)
        @providers << provider
        self
      end

      # Removes a provider by key.
      # @param key [Symbol] provider key
      # @return [Provider, nil] removed provider or nil
      def remove_provider(key)
        removed = @providers.find { |p| p.context_key == key }
        @providers.reject! { |p| p.context_key == key }
        removed
      end

      # Gets a provider by key.
      # @param key [Symbol] provider key
      # @return [Provider, nil]
      def [](key)
        @providers.find { |p| p.context_key == key }
      end

      private

      def collect_contributions_with_metrics(budgets, meter)
        contributions = []
        excluded = []
        current_meter = meter

        @providers.each do |provider|
          result, current_meter = process_provider(provider, budgets, current_meter, excluded)
          contributions << result if result
        end

        [contributions, current_meter, excluded]
      end

      def process_provider(provider, budgets, meter, excluded)
        result = contribution_for(provider, budgets)
        return track_excluded(provider, excluded, meter) unless result

        result[:tokens] = estimate_tokens(result[:content])
        [result, meter.add(result[:tokens])]
      end

      def track_excluded(provider, excluded, meter)
        excluded << provider.context_key if provider.context_active?
        [nil, meter]
      end

      def contribution_for(provider, budgets)
        return unless provider.context_active?

        budget = budgets[provider.context_key] || 0
        return if budget < BudgetAllocator::MIN_PROVIDER_BUDGET && provider.context_optional?

        content = safe_contribute(provider, budget)
        return if content.nil? || content.empty?

        { key: provider.context_key, layer: provider.context_layer, priority: provider.context_priority, content: }
      end

      def safe_contribute(provider, budget)
        provider.context_contribution(budget:)
      rescue StandardError => e
        "# [Error from #{provider.context_key}: #{e.message}]"
      end

      def estimate_tokens(content) = (content.to_s.length / CHARS_PER_TOKEN.to_f).ceil

      def organize_by_layer(contributions)
        Layer::ALL.to_h do |layer|
          [layer.name, contributions.select { |c| c[:layer] == layer }.sort_by { |c| -c[:priority] }]
        end
      end

      def layer_content_map(layered)
        layered.transform_values { |cs| cs.map { |c| c[:content] }.join("\n\n") }
      end

      def format_layers(layered)
        sections = layered.filter_map do |_layer_name, contributions|
          next if contributions.empty?

          contributions.map { |c| c[:content] }.join("\n\n")
        end
        RubyPresenter.context_block(sections)
      end

      def build_metadata(contributions, budgets)
        { provider_count: contributions.size, total_budget: @allocator.total_budget, budgets:,
          layers_used: contributions.map { |c| c[:layer].name }.uniq,
          providers_included: contributions.map { |c| c[:key] } }
      end

      def build_metrics(contributions, budgets, meter, excluded)
        provider_contributions = contributions.to_h { |c| [c[:key], c[:tokens]] }
        Types::ContextAssemblyMetrics.new(
          provider_budgets: budgets,
          provider_contributions:,
          total_budget: @allocator.total_budget,
          total_used: meter.used,
          providers_included: contributions.map { |c| c[:key] },
          providers_excluded: excluded
        )
      end
    end
  end
end
