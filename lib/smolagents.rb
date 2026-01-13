require_relative "smolagents/version"
require_relative "smolagents/errors"
require_relative "smolagents/logging"
require_relative "smolagents/security"
require_relative "smolagents/telemetry"
require_relative "smolagents/utilities"
require_relative "smolagents/http"
require_relative "smolagents/events"
require_relative "smolagents/concerns"
require_relative "smolagents/types"
require_relative "smolagents/config"
require_relative "smolagents/executors"
require_relative "smolagents/models"
require_relative "smolagents/tools"
require_relative "smolagents/pipeline"
require_relative "smolagents/persistence"
require_relative "smolagents/orchestrators"
require_relative "smolagents/agents"
require_relative "smolagents/builders"

# Smolagents: Delightfully simple agents that think in Ruby.
#
# Smolagents provides a complete framework for building AI agents in Ruby.
# It includes:
#
# - **Agents**: CodeAgent (writes Ruby code), ToolCallingAgent (JSON tool calls)
# - **Models**: OpenAI, Anthropic, LiteLLM, and local model support
# - **Tools**: Built-in tools for search, web visits, and custom tool creation
# - **Builders**: Fluent API for agent and team configuration
# - **Pipeline**: Composable tool execution chains
# - **Orchestrators**: Multi-agent coordination and sub-agent management
# - **Executors**: Sandboxed Ruby code execution (Ruby, Docker, Ractor)
# - **Telemetry**: Event-driven observability and tracing
# - **Persistence**: Agent state serialization and loading
#
# @example Creating and running a code agent
#   agent = Smolagents.code
#     .model { OpenAIModel.new(model_id: "gpt-4") }
#     .tools(:web_search, :visit_webpage)
#     .build
#
#   result = agent.run("Find recent Ruby news")
#
# @example Creating a tool-calling agent
#   agent = Smolagents.tool_calling
#     .model { OpenAIModel.new(model_id: "gpt-4") }
#     .tools(:web_search)
#     .build
#
# @example Composing tools with pipelines
#   result = Smolagents.run(:search, query: "Ruby 4.0")
#     .then(:visit_webpage) { |r| { url: r.first[:url] } }
#     .pluck(:content)
#     .run
#
# @see Agents Agent types and implementation
# @see Models LLM adapters and configurations
# @see Tools Tool system and built-in tools
# @see Pipeline Composable tool execution
# @see Builders Fluent configuration DSL
#
module Smolagents
  class << self
    # ============================================================
    # Agent Shortcuts - Ergonomic entry points
    # ============================================================

    # Creates a code agent builder.
    #
    # CodeAgent generates Ruby code to call tools, making it suitable for:
    # - Complex multi-step reasoning
    # - Writing and executing Ruby code
    # - Models with strong code generation capabilities
    #
    # The agent automatically includes the final_answer tool.
    #
    # @example Minimal agent
    #   Smolagents.code
    #     .model { OpenAI.gpt4 }
    #     .build
    #
    # @example With tools and event handlers
    #   Smolagents.code
    #     .model { LMStudio.llama3 }
    #     .tools(:web_search, :visit_webpage)
    #     .on(:step_complete) { |e| puts e }
    #     .max_steps(10)
    #     .build
    #
    # @return [Builders::AgentBuilder] Code agent builder (fluent interface)
    #
    # @see Builders::AgentBuilder Configuration options
    # @see Agents::CodeAgent Implementation details
    def code
      Builders::AgentBuilder.create(:code).tools(:final_answer)
    end

    # Creates a tool-calling agent builder.
    #
    # ToolCallingAgent uses JSON-formatted tool calls, making it suitable for:
    # - Models with native tool use support (OpenAI, Claude, etc.)
    # - Reliable tool invocation
    # - Efficient multi-step tasks
    #
    # The agent automatically includes the final_answer tool.
    #
    # @example
    #   Smolagents.tool_calling
    #     .model { OpenAI.gpt4 }
    #     .tools(:web_search)
    #     .max_steps(8)
    #     .build
    #
    # @return [Builders::AgentBuilder] Tool-calling agent builder (fluent interface)
    #
    # @see Builders::AgentBuilder Configuration options
    # @see Agents::ToolCallingAgent Implementation details
    def tool_calling
      Builders::AgentBuilder.create(:tool_calling).tools(:final_answer)
    end

    # Creates a new agent builder with specified type.
    #
    # This is the generic form used internally by {#code} and {#tool_calling}.
    # Most users should prefer the convenience methods instead.
    #
    # @param type [Symbol] Agent type (:code or :tool_calling)
    # @return [Builders::AgentBuilder] New agent builder
    #
    # @example
    #   agent = Smolagents.agent(:code).model { ... }.build
    #
    # @see #code For code-generating agents
    # @see #tool_calling For JSON tool-calling agents
    def agent(type)
      Builders::AgentBuilder.create(type)
    end

    # ============================================================
    # Team and Coordination
    # ============================================================

    # Creates a new team builder for multi-agent composition.
    #
    # Teams coordinate multiple agents to solve complex tasks collaboratively.
    # Use them for:
    # - Dividing work across specialized agents
    # - Orchestrating sequential workflows
    # - Managing communication between agents
    #
    # @example Creating a research and writing team
    #   Smolagents.team
    #     .model { OpenAI.gpt4 }
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research the topic, then write a summary")
    #     .build
    #
    # @return [Builders::TeamBuilder] New team builder (fluent interface)
    #
    # @see Builders::TeamBuilder Configuration options
    # @see Orchestrators Multi-agent orchestration
    def team
      Builders::TeamBuilder.create
    end

    # ============================================================
    # Model Configuration
    # ============================================================

    # Creates a new model builder.
    #
    # Models handle communication with LLMs. Smolagents supports:
    # - OpenAI (gpt-4, gpt-3.5-turbo, etc.)
    # - Anthropic (Claude models)
    # - LiteLLM (multi-provider)
    # - Local models (via LM Studio, Ollama, etc.)
    #
    # @param type_or_model [Symbol, Model] Model type (:openai, :anthropic, :litellm) or existing model instance
    # @return [Builders::ModelBuilder] New model builder (fluent interface)
    #
    # @example OpenAI model
    #   Smolagents.model(:openai).id("gpt-4").api_key("sk-...").build
    #
    # @example Local model via LiteLLM
    #   Smolagents.model(:litellm).id("openrouter/meta-llama/llama-3-8b").build
    #
    # @see Builders::ModelBuilder Configuration options
    # @see Models Available model types
    def model(type_or_model = :openai)
      Builders::ModelBuilder.create(type_or_model)
    end

    # ============================================================
    # Pipeline and Tool Execution
    # ============================================================

    # Creates a new empty pipeline.
    #
    # Pipelines compose tool calls into reusable execution chains.
    # They're ideal for:
    # - Multi-step workflows
    # - Data transformation chains
    # - Converting into reusable tools
    #
    # @return [Pipeline] New empty pipeline
    #
    # @example Basic pipeline
    #   Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .run(query: "Ruby")
    #
    # @example Converting to a tool
    #   research = Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .take(3)
    #
    #   tool = research.as_tool("quick_search", "Search and return top 3 results")
    #   agent = Smolagents.code.model { ... }.tools(tool).build
    #
    # @see Pipeline Full API documentation
    def pipeline
      Pipeline.new
    end

    # Executes a tool and returns a chainable pipeline.
    #
    # Convenience method for starting a pipeline with a single tool call.
    # The result is a Pipeline that can be extended with additional steps.
    #
    # @param tool_name [Symbol, String] Name of the tool to execute
    # @param args [Hash] Arguments to pass to the tool
    # @return [Pipeline] Pipeline with the tool call added (fluent interface)
    #
    # @example Chaining operations
    #   Smolagents.run(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .pluck(:content)
    #     .run
    #
    # @example Equivalent to
    #   Smolagents.pipeline
    #     .call(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .pluck(:content)
    #     .run
    #
    # @see #pipeline For creating empty pipelines
    # @see Pipeline Full API documentation
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end
  end

  # Re-exports for backward compatibility and convenience.
  # These allow code to use Smolagents::ClassName instead of the full namespace path.

  # Logging and debugging utilities.
  # @see Logging::AgentLogger Structured logging for agent execution
  AgentLogger = Logging::AgentLogger

  # Security utilities for protecting agents and handling sensitive data.
  # @see Security::PromptSanitizer Prompt injection detection and prevention
  # @see Security::SecretRedactor API key and password redaction
  PromptSanitizer = Security::PromptSanitizer
  SecretRedactor = Security::SecretRedactor

  # Observability and monitoring for agent operations.
  # @see Telemetry::Instrumentation Data collection for events
  Instrumentation = Telemetry::Instrumentation

  # Utility functions for pattern matching, prompts, and analysis.
  # @see Utilities::PatternMatching Ruby 3.0+ pattern matching utilities
  # @see Utilities::Prompts System prompt management
  # @see Utilities::Comparison Text and semantic comparison
  # @see Utilities::Confidence Confidence scoring for outputs
  PatternMatching = Utilities::PatternMatching
  Prompts = Utilities::Prompts
  Comparison = Utilities::Comparison
  Confidence = Utilities::Confidence

  # HTTP utilities for making requests from agents and tools.
  # @see Http::UserAgent RFC 7231 compliant User-Agent strings
  UserAgent = Http::UserAgent

  # Testing and benchmarking framework (autoloaded on first use).
  # @see Testing Model evaluation and compatibility testing
  autoload :Testing, "smolagents/testing"
end
