# Context orchestration integration for agent runtime.
#
# Initializes and manages the Context::Orchestrator, wiring it to
# runtime state via adapter providers. Provides a unified context
# assembly point replacing scattered injections.
#
# == Dependencies
#
# This concern requires MessageFormatting to be available in the including
# class. MessageFormatting provides +inject_before_last_user+ used by
# +inject_orchestrated_context+.
#
# The dependency is satisfied when including in classes that also include
# Concerns::Formatting or Concerns::MessageFormatting directly.
#
# @example Access assembled context
#   context = assemble_context
#   context.content  #=> "# == Step ==\n# Step 3 of 10..."
#
# @see Concerns::MessageFormatting#inject_before_last_user
require_relative "../../context/orchestrator"
require_relative "../../context/providers/base"

module Smolagents
  module Concerns
    # @note Requires MessageFormatting for inject_before_last_user
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
      # Providers return nil from context_contribution when inactive.
      # @return [Array<Context::Provider>]
      def build_runtime_providers
        [
          # Layer 1 (PERSISTENT) - survives truncation
          Context::Providers.working_memory(self),
          # Layer 2 (STRATEGIC)
          Context::Providers.planning(self),
          Context::Providers.goals(self),
          Context::Providers.reflections(self),
          # Layer 3 (TACTICAL)
          Context::Providers.step_context(self)
        ]
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
