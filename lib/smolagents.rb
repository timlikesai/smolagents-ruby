require_relative "smolagents/version"
require_relative "smolagents/errors"
require_relative "smolagents/config"
require_relative "smolagents/logging"
require_relative "smolagents/security"
require_relative "smolagents/telemetry"
require_relative "smolagents/utilities"
require_relative "smolagents/http"
require_relative "smolagents/events"
require_relative "smolagents/concerns"
require_relative "smolagents/types"
require_relative "smolagents/executors"
require_relative "smolagents/models"
require_relative "smolagents/tools"
require_relative "smolagents/pipeline"
require_relative "smolagents/persistence"
require_relative "smolagents/orchestrators"
require_relative "smolagents/agents"
require_relative "smolagents/builders"
require_relative "smolagents/toolkits"
require_relative "smolagents/personas"
require_relative "smolagents/specializations"
require_relative "smolagents/discovery"
require_relative "smolagents/interactive"
require_relative "smolagents/dsl"
require_relative "smolagents/exports"

# Smolagents: Delightfully simple agents that think in Ruby.
#
# Smolagents provides a complete framework for building AI agents in Ruby.
# Not a Python port -- a Ruby-first design using `Data.define`, pattern matching,
# and fluent APIs. The interface is designed to be intuitive and idiomatic.
#
# == Core Components
#
# - **Agents**: CodeAgent (writes Ruby code), ToolAgent (JSON tool calls)
# - **Models**: OpenAI, Anthropic, LiteLLM, and local model support
# - **Tools**: Built-in tools for search, web visits, and custom tool creation
# - **Toolkits**: Tool groupings (:search, :web, :data, :research)
# - **Personas**: Behavioral instruction templates
# - **Builders**: Fluent API for agent and team configuration
# - **Pipeline**: Composable tool execution chains
# - **Orchestrators**: Multi-agent coordination and sub-agent management
# - **Executors**: Sandboxed Ruby code execution (LocalRuby, Ractor)
# - **Telemetry**: Event-driven observability and tracing
# - **Persistence**: Agent state serialization and loading
#
# == Quick Start
#
# @example Minimal agent (returns AgentBuilder)
#   builder = Smolagents.agent
#   builder.class.name.include?("Builder")  #=> true
#
# @example Check available toolkits
#   Smolagents::Toolkits.names  #=> [:search, :web, :data, :research]
#
# @example Check available personas
#   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, :calculator, :scraper]
#
# @example Check available specializations
#   Smolagents::Specializations.names.include?(:researcher)  #=> true
#
# == Builder Method Distinctions
#
# Agents are configured with three key methods. Understanding the distinction
# is essential for effective agent composition:
#
# [+.tools(:name)+]
#   Adds a toolkit (auto-expands to individual tools) or individual tools.
#   *What the agent can use.* Toolkits are named groups of related tools.
#
# [+.as(:name)+]
#   Applies a persona (behavioral instructions only).
#   *How the agent should behave.* Does not add any tools.
#
# [+.with(:name)+]
#   Adds a specialization (convenience bundle: toolkit + persona together).
#   *Shorthand for .tools + .as combined.*
#
# The relationship:
#   .tools(:search).as(:researcher)  ==  .with(:researcher)
#
# Use +.tools+ and +.as+ for fine-grained control. Use +.with+ for convenience.
#
# @example Using .tools (add tools only)
#   agent = Smolagents.agent
#     .tools(:search, :web)         # Adds search + web tools
#     .model { my_model }
#     .build
#
# @example Using .as (add persona only)
#   agent = Smolagents.agent
#     .tools(:search)               # Must add tools separately
#     .as(:researcher)              # Adds behavioral instructions
#     .model { my_model }
#     .build
#
# @example Using .with (convenience: tools + persona)
#   agent = Smolagents.agent
#     .with(:researcher)            # Same as .tools(:research).as(:researcher)
#     .model { my_model }
#     .build
#
# @example Combining methods for customization
#   agent = Smolagents.agent
#     .with(:researcher)            # Start with researcher bundle
#     .tools(:data)                 # Add extra data tools
#     .instructions("Be concise")   # Add custom instructions
#     .model { my_model }
#     .build
#
# == Type System
#
# Smolagents uses Ruby 4.0's `Data.define` pattern for immutable data types.
# Key types are re-exported at the module level for convenience:
#
# @example Working with types
#   Smolagents::TokenUsage.ancestors.include?(Data)  #=> true
#   Smolagents::ToolCall.ancestors.include?(Data)  #=> true
#   Smolagents::RunResult.ancestors.include?(Data)  #=> true
#
# @see Toolkits Available toolkits (:search, :web, :data, :research)
# @see Personas Available personas (:researcher, :fact_checker, :analyst, :calculator, :scraper)
# @see Specializations Available specializations (:researcher, :fact_checker, :data_analyst, :calculator, :web_scraper)
# @see Builders::AgentBuilder Full builder API
# @see Models Model adapters for different LLM providers
# @see Tools::Tool Base class for creating custom tools
#
module Smolagents
  # Entry point DSL methods (agent, model, team, pipeline, etc.)
  extend DSL

  # Type and constant re-exports for top-level access
  extend Exports

  # Testing and benchmarking framework (autoloaded on first use).
  #
  # Provides utilities for model evaluation, compatibility testing,
  # and benchmark runs. Autoloaded to avoid startup overhead.
  #
  # @see Testing Model evaluation and compatibility testing
  autoload :Testing, "smolagents/testing"
end

# ============================================================
# Auto-activate Interactive Mode
# ============================================================
#
# When loaded in an interactive session (IRB, Pry, Rails console),
# automatically scan for models and show a helpful welcome message.
# This runs after all constants are defined.
#
# Set SMOLAGENTS_QUIET=1 to disable the welcome message.
# Set SMOLAGENTS_NO_DISCOVER=1 to skip discovery entirely.

if Smolagents::Interactive.session? && !ENV["SMOLAGENTS_NO_DISCOVER"]
  Smolagents::Interactive.activate!(quiet: ENV.fetch("SMOLAGENTS_QUIET", nil))

  # Auto-enable logging subscriber for agent progress visibility
  # Users see step/tool output during runs. Disable with SMOLAGENTS_QUIET=1.
  Smolagents::Telemetry::LoggingSubscriber.enable(level: :info) unless ENV["SMOLAGENTS_QUIET"]
end
