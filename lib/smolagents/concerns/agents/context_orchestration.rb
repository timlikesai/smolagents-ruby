# Context orchestration integration for agent runtime.
#
# Initializes and manages the Context::Orchestrator, wiring it to
# runtime state via adapter providers. Provides a unified context
# assembly point replacing scattered injections.
#
# @example Access assembled context
#   context = assemble_context
#   context.content  #=> "# == Step ==\n# Step 3 of 10..."
require_relative "../../context/orchestrator"
require_relative "../../context/providers/base"

module Smolagents
  module Concerns
    module ContextOrchestration
      include MessageFormatting

      def self.included(base)
        base.attr_reader :context_orchestrator
      end

      private

      # Initializes context orchestration with runtime-bound providers.
      # Called during runtime setup, after memory and planning are configured.
      def initialize_context_orchestration
        providers = build_runtime_providers
        @context_orchestrator = Context::Orchestrator.new(providers:)
      end

      # Builds adapter providers bound to this runtime instance.
      # @return [Array<Context::Provider>]
      def build_runtime_providers
        providers = []
        providers << Context::Providers.step_context(self)
        providers << Context::Providers.planning(self) if @planning_interval
        providers << Context::Providers.goals(self) if goal_tracking_context_enabled?
        providers << Context::Providers.reflections(self) if reflection_memory_enabled?
        providers
      end

      # Checks if reflection memory is enabled on this runtime.
      def reflection_memory_enabled?
        defined?(@reflection_config) && @reflection_config&.enabled
      end

      # Checks if goal tracking should contribute to context.
      def goal_tracking_context_enabled?
        respond_to?(:goal_tracking_enabled?) && goal_tracking_enabled?
      end

      # Assembles context for current runtime state.
      # @return [Context::AssemblyResult]
      def assemble_context
        @context_orchestrator.assemble(
          task: current_task_description,
          step: @ctx&.step_number || 0
        )
      end

      # Gets current task description for relevance scoring.
      def current_task_description
        @memory&.steps&.find { |s| s.is_a?(Types::TaskStep) }&.task || ""
      end

      # Injects orchestrated context into messages.
      # Replaces scattered inject_* methods with unified assembly.
      #
      # @param messages [Array<ChatMessage>] Original messages
      # @return [Array<ChatMessage>] Messages with context injected
      def inject_orchestrated_context(messages)
        result = assemble_context
        return messages if result.content.empty?

        inject_before_last_user(messages, ChatMessage.system(result.content))
      end
    end
  end
end
