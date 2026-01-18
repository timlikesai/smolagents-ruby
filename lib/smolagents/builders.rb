require_relative "builders/support"
require_relative "builders/base"
require_relative "builders/dsl"
require_relative "builders/event_handlers"
require_relative "builders/agent_builder"
require_relative "builders/team_builder"
require_relative "builders/model_builder"
require_relative "builders/test_builder"

module Smolagents
  # Fluent builder DSL for configuring agents, models, and teams.
  #
  # All builders are immutable Data.define types that return new instances
  # on each method call. This enables safe method chaining and introspection.
  #
  # @example Building an agent
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   builder = Smolagents.agent.model { @model }.tools(:search)
  #   builder.is_a?(Smolagents::Builders::AgentBuilder)  #=> true
  #
  # @example Building a model with reliability
  #   builder = Smolagents.model(:openai).id("gpt-4")
  #   builder.is_a?(Smolagents::Builders::ModelBuilder)  #=> true
  #
  # @example Building a team
  #   builder = Smolagents.team
  #   builder.is_a?(Smolagents::Builders::TeamBuilder)  #=> true
  #
  # @see AgentBuilder For building agents
  # @see ModelBuilder For building models with reliability features
  # @see TeamBuilder For building multi-agent teams
  module Builders
    # Agent class (one type - all agents write Ruby code)
    AGENT_CLASS = "Smolagents::Agents::Agent".freeze

    # @deprecated Use AGENT_CLASS instead
    AGENT_TYPES = {
      code: AGENT_CLASS,
      tool: AGENT_CLASS
    }.freeze
  end
end
