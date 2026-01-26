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
# @example Provider with relevance scoring
#   class SmartProvider
#     include Smolagents::Context::Provider
#
#     def context_key = :smart
#     def context_layer = Layer::TACTICAL
#     def context_contribution(budget:) = @cached_content
#     def context_relevance(task:, step:) = task.include?("search") ? 1.0 : 0.5
#   end
require_relative "layer"

module Smolagents
  module Context
    module Provider
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

      # Required: the content to contribute.
      # @param budget [Integer] token budget available for this provider
      # @return [String, nil] content to include, or nil to skip
      def context_contribution(budget:)
        raise NotImplementedError, "#{self.class} must implement #context_contribution"
      end

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
    end
  end
end
