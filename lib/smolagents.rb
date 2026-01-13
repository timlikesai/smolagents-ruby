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

module Smolagents
  class << self
    # ============================================================
    # Agent Shortcuts - Ergonomic entry points
    # ============================================================

    # Create a code agent builder (writes Ruby code to call tools)
    #
    # @example Minimal agent
    #   Smolagents.code
    #     .model { OpenAI.gpt4 }
    #     .build
    #
    # @example With tools and handlers
    #   Smolagents.code
    #     .model { LMStudio.llama3 }
    #     .tools(:web_search, :visit_webpage)
    #     .on(:step_complete) { |e| puts e }
    #     .build
    #
    # @return [Builders::AgentBuilder] Code agent builder with final_answer included
    def code
      Builders::AgentBuilder.create(:code).tools(:final_answer)
    end

    # Create a tool-calling agent builder (uses JSON tool calls)
    #
    # @example
    #   Smolagents.tool_calling
    #     .model { OpenAI.gpt4 }
    #     .tools(:web_search)
    #     .build
    #
    # @return [Builders::AgentBuilder] Tool-calling agent builder with final_answer included
    def tool_calling
      Builders::AgentBuilder.create(:tool_calling).tools(:final_answer)
    end

    # Create a new agent builder (generic form)
    #
    # @param type [Symbol] Agent type (:code or :tool_calling)
    # @return [Builders::AgentBuilder] New agent builder
    def agent(type)
      Builders::AgentBuilder.create(type)
    end

    # ============================================================
    # Team and Coordination
    # ============================================================

    # Create a new team builder for multi-agent composition
    #
    # @example
    #   Smolagents.team
    #     .model { OpenAI.gpt4 }
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research then write")
    #     .build
    #
    # @return [Builders::TeamBuilder] New team builder
    def team
      Builders::TeamBuilder.create
    end

    # ============================================================
    # Model Configuration
    # ============================================================

    # Create a new model builder
    #
    # @example
    #   Smolagents.model(:openai).id("gpt-4").build
    #
    # @param type_or_model [Symbol, Model] Model type or existing model instance
    # @return [Builders::ModelBuilder] New model builder
    def model(type_or_model = :openai)
      Builders::ModelBuilder.create(type_or_model)
    end

    # ============================================================
    # Pipeline and Tool Execution
    # ============================================================

    # Create a new pipeline for composing tools
    #
    # @example
    #   Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .run(query: "Ruby")
    #
    # @return [Pipeline] New empty pipeline
    def pipeline
      Pipeline.new
    end

    # Execute a tool and return a chainable pipeline
    #
    # @param tool_name [Symbol, String] Tool to execute
    # @param args [Hash] Arguments for the tool
    # @return [Pipeline] Pipeline with the tool call added
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end
  end

  # Re-exports for backward compatibility.
  # These allow code to use Smolagents::ClassName instead of the full namespace path.

  # Logging
  AgentLogger = Logging::AgentLogger

  # Security
  PromptSanitizer = Security::PromptSanitizer
  SecretRedactor = Security::SecretRedactor

  # Telemetry
  Instrumentation = Telemetry::Instrumentation

  # Utilities
  PatternMatching = Utilities::PatternMatching
  Prompts = Utilities::Prompts
  Comparison = Utilities::Comparison
  Confidence = Utilities::Confidence

  # HTTP
  UserAgent = Http::UserAgent

  # Testing (autoload - only loaded when needed)
  autoload :Testing, "smolagents/testing"
end
