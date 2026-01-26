# Context orchestration for agent message assembly.
#
# Provides a layered context model with provider-based contributions,
# budget allocation, and Ruby-native formatting.
#
# @example Basic usage
#   orchestrator = Context::Orchestrator.new(providers: [goal_provider])
#   result = orchestrator.assemble(task: "Find info", step: 1)
#   puts result.content
#
# @see Context::Layer for layer definitions
# @see Context::Provider for provider protocol
# @see Context::Orchestrator for assembly logic
module Smolagents
  module Context
    autoload :Layer, "smolagents/context/layer"
    autoload :Provider, "smolagents/context/provider"
    autoload :Registry, "smolagents/context/registry"
    autoload :RubyPresenter, "smolagents/context/ruby_presenter"
    autoload :BudgetAllocator, "smolagents/context/budget_allocator"
    autoload :Orchestrator, "smolagents/context/orchestrator"
    autoload :Providers, "smolagents/context/providers/base"
  end
end
