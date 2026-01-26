# Context orchestrator for agent message assembly.
#
# Queries registered providers, allocates budgets, and builds
# layered context for model consumption.
#
# @example Basic usage
#   orchestrator = Orchestrator.new(providers: [goal_provider, plan_provider])
#   result = orchestrator.assemble(task: "Find info", step: 1)
#   result.content  #=> "# == Goal ==\n# Find info\n..."
require_relative "layer"
require_relative "budget_allocator"
require_relative "ruby_presenter"

module Smolagents
  module Context
    # Result of context assembly.
    AssemblyResult = Data.define(:content, :layers, :metadata) do
      def to_s = content

      def layer_content(layer) = layers[layer.name]
    end

    class Orchestrator
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
        contributions = collect_contributions(budgets)
        layered = organize_by_layer(contributions)
        content = format_layers(layered)

        layers = layer_content_map(layered)
        metadata = build_metadata(contributions, budgets)
        AssemblyResult.new(content:, layers:, metadata:)
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

      def collect_contributions(budgets)
        @providers.filter_map { |provider| contribution_for(provider, budgets) }
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
    end
  end
end
