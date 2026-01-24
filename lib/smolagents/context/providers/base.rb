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

      # Builds plan content from runtime state using public APIs.
      def self.build_plan_content(runtime)
        return nil unless runtime.planning_interval&.positive?

        ctx = runtime.plan_context
        return nil unless ctx&.initialized?
        return nil if ctx.plan.nil? || ctx.plan.empty?

        "CURRENT PLAN:\n#{ctx.plan}\n\nExecute the next step in this plan."
      end

      # Creates reflection provider bound to a runtime.
      # @param runtime [AgentRuntime] runtime with reflection memory
      # @return [AdapterProvider]
      def self.reflections(runtime)
        AdapterProvider.build(
          key: :reflections,
          layer: Layer::STRATEGIC,
          priority: 60,
          content_proc: -> { build_reflection_content(runtime) }
        )
      end

      # Builds reflection content from runtime state using public APIs.
      def self.build_reflection_content(runtime)
        return nil unless runtime.reflection_config&.enabled

        store = runtime.reflection_store
        return nil unless store

        task = runtime.send(:current_task_description)
        reflections = store.relevant_to(task, limit: 3)
        return nil if reflections.empty?

        format_reflections(reflections)
      end

      def self.format_reflections(reflections)
        body = reflections.map.with_index(1) { |r, i| "#{i}. #{r.to_context}" }.join("\n\n")
        "# == Lessons from Previous Attempts ==\n\n#{body}"
      end

      # Creates goals provider bound to a runtime.
      # @param runtime [AgentRuntime] runtime with goal tracking
      # @return [AdapterProvider]
      def self.goals(runtime)
        AdapterProvider.build(
          key: :goals,
          layer: Layer::STRATEGIC,
          priority: 70,
          content_proc: -> { build_goal_content(runtime) }
        )
      end

      # Builds goal content from runtime state using public APIs.
      def self.build_goal_content(runtime)
        return nil unless runtime.respond_to?(:goal_tracking_enabled?)
        return nil unless runtime.goal_tracking_enabled?
        return nil unless runtime.respond_to?(:build_goal_context)

        runtime.build_goal_context
      end
    end
  end
end
