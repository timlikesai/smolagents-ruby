require_relative "builders/base"
require_relative "builders/event_handlers"
require_relative "builders/agent_builder"
require_relative "builders/team_builder"
require_relative "builders/model_builder"
require_relative "builders/dsl"

module Smolagents
  # Fluent builder DSL for configuring agents, models, and teams.
  #
  # All builders are immutable Data.define types that return new instances
  # on each method call. This enables safe method chaining and introspection.
  #
  # @example Building an agent
  #   agent = Smolagents.agent
  #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  #     .tools(:search)
  #     .build
  #
  # @example Building a model with reliability
  #   model = Smolagents.model(:openai)
  #     .id("gpt-4")
  #     .with_retry(max_attempts: 3)
  #     .build
  #
  # @example Building a team
  #   team = Smolagents.team
  #     .agent(researcher, as: "researcher")
  #     .agent(writer, as: "writer")
  #     .coordinate("Research then write")
  #     .build
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
