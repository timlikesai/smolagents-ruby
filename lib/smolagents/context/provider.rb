# Provider protocol for context contributions.
#
# Include this module in any concern to make it a context provider.
# Providers contribute content to specific layers during context assembly.
#
# @example Minimal provider
#   class MyProvider
#     include Smolagents::Context::Provider
#
#     def context_key = :my_context
#     def context_layer = Smolagents::Context::Layer::STRATEGIC
#     def context_contribution(budget:) = "My context content"
#   end
#
# @example Provider with truncation strategy
#   class SmartProvider
#     include Smolagents::Context::Provider
#
#     def context_key = :smart
#     def context_layer = Layer::TACTICAL
#     def context_truncation_strategy = :adaptive
#     def generate_contribution(budget:) = @cached_content
#     def context_relevance(task:, step:) = task.include?("search") ? 1.0 : 0.5
#   end
require_relative "../types/context/layer"
require_relative "../errors"

module Smolagents
  module Context
    # Error raised when content exceeds budget with :fail strategy.
    class BudgetExceededError < Smolagents::Errors::AgentError
      attr_reader :budget, :actual

      def initialize(message, budget: nil, actual: nil)
        @budget = budget
        @actual = actual
        super(message)
      end
    end

    module Provider
      # Supported truncation strategies.
      TRUNCATION_STRATEGIES = %i[adaptive truncate fail none].freeze

      # Characters per token for estimation (matches token_estimation.rb).
      CHARS_PER_TOKEN = 4

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def context_provider? = true
      end

      # Required: unique key for this provider.
      # @return [Symbol]
      def context_key
        raise NotImplementedError, "#{self.class} must implement #context_key"
      end

      # Required: which layer this provider contributes to.
      # @return [Layer]
      def context_layer
        raise NotImplementedError, "#{self.class} must implement #context_layer"
      end

      # Returns contribution with budget enforcement.
      # @param budget [Integer] token budget available for this provider
      # @param truncation_strategy [Symbol] one of :adaptive, :truncate, :fail, :none
      # @return [String, nil] content to include, or nil to skip
      def context_contribution(budget:, truncation_strategy: nil)
        strategy = truncation_strategy || context_truncation_strategy
        content = generate_contribution(budget:)
        return content unless content

        enforce_budget(content, budget, strategy)
      end

      # Override this to generate content. Called by context_contribution.
      # @param budget [Integer] token budget hint
      # @return [String, nil] raw content before budget enforcement
      def generate_contribution(budget:)
        raise NotImplementedError, "#{self.class} must implement #generate_contribution"
      end

      # Optional: default truncation strategy for this provider.
      # @return [Symbol] one of :adaptive, :truncate, :fail, :none (default: :none)
      def context_truncation_strategy = :none

      # Optional: priority within layer (higher = included first).
      # @return [Integer] priority (default: 50)
      def context_priority = 50

      # Optional: relevance score for current context.
      # @param task [String] current task
      # @param step [Integer] current step number
      # @return [Float] 0.0 to 1.0 (default: 1.0)
      def context_relevance(**) = 1.0

      # Optional: whether this provider can be omitted under budget pressure.
      # @return [Boolean] true if optional (default: true)
      def context_optional? = true

      # Optional: whether this provider is currently active.
      # @return [Boolean] true if active (default: true)
      def context_active? = true

      # Estimates token count for content.
      # @param content [String] content to estimate
      # @return [Integer] estimated token count
      def estimate_tokens(content) = (content.to_s.length / CHARS_PER_TOKEN.to_f).ceil

      private

      def enforce_budget(content, budget, strategy)
        return content if strategy == :none

        case strategy
        when :adaptive then apply_adaptive(content, budget)
        when :truncate then truncate_to_budget(content, budget)
        when :fail then raise_if_over_budget(content, budget)
        else content
        end
      end

      def apply_adaptive(content, budget)
        estimate_tokens(content) <= budget ? content : truncate_to_budget(content, budget)
      end

      def truncate_to_budget(content, budget)
        max_chars = budget * CHARS_PER_TOKEN
        content.to_s[0, max_chars]
      end

      def raise_if_over_budget(content, budget)
        estimated = estimate_tokens(content)
        return content if estimated <= budget

        raise BudgetExceededError.new(
          "Content exceeds budget: #{estimated} tokens > #{budget} budget",
          budget:, actual: estimated
        )
      end
    end
  end
end
