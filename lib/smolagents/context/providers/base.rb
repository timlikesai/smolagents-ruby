# Base adapter for runtime-bound context providers.
#
# Wraps a callable (proc/lambda) to create providers that can access
# runtime state. Enables clean delegation without exposing internals.
#
# @example Create from a runtime method
#   provider = AdapterProvider.new(
#     key: :step_context,
#     layer: Layer::TACTICAL,
#     content_proc: -> { runtime.build_step_context }
#   )
require_relative "../layer"
require_relative "../provider"

module Smolagents
  module Context
    module Providers
      # Flexible adapter provider using a content proc.
      AdapterProvider = Data.define(:key, :layer, :content_proc, :priority, :optional) do
        include Provider

        def self.build(key:, layer:, content_proc:, priority: 50, optional: true)
          new(key:, layer:, content_proc:, priority:, optional:)
        end

        def context_key = key
        def context_layer = layer
        def context_priority = priority
        def context_optional? = optional
        def context_contribution(budget:) = content_proc.call # rubocop:disable Lint/UnusedMethodArgument
      end

      # Creates step context provider bound to a runtime.
      # @param runtime [AgentRuntime] runtime with build_step_context method
      # @return [AdapterProvider]
      def self.step_context(runtime)
        AdapterProvider.build(
          key: :step_context,
          layer: Layer::TACTICAL,
          priority: 90,
          content_proc: -> { runtime.send(:build_step_context) }
        )
      end

      # Creates planning provider bound to a runtime.
      # @param runtime [AgentRuntime] runtime with plan_context
      # @return [AdapterProvider]
      def self.planning(runtime)
        AdapterProvider.build(
          key: :planning,
          layer: Layer::STRATEGIC,
          priority: 80,
          content_proc: -> { build_plan_content(runtime) }
        )
      end

      # Builds plan content from runtime state.
      def self.build_plan_content(runtime)
        return nil unless runtime.instance_variable_get(:@planning_interval)&.positive?

        plan_context = runtime.instance_variable_get(:@plan_context)
        return nil unless plan_context&.initialized?
        return nil if plan_context.plan.nil? || plan_context.plan.empty?

        "CURRENT PLAN:\n#{plan_context.plan}\n\nExecute the next step in this plan."
      end
    end
  end
end
