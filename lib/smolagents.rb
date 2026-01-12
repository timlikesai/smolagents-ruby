require_relative "smolagents/version"
require_relative "smolagents/utilities/secret_redactor"
require_relative "smolagents/errors"
require_relative "smolagents/utilities"
require_relative "smolagents/telemetry"
require_relative "smolagents/user_agent"
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
    # @example
    #   Smolagents.run(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .result
    #
    # @param tool_name [Symbol, String] Tool to execute
    # @param args [Hash] Arguments for the tool
    # @return [Pipeline] Pipeline with the tool call added
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end

    # Create a new agent builder
    #
    # @example
    #   Smolagents.agent(:code)
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .tools(:google_search, :visit_webpage)
    #     .max_steps(10)
    #     .on(:step_complete) { |step| puts step }
    #     .build
    #
    # @param type [Symbol] Agent type (:code or :tool_calling)
    # @return [Builders::AgentBuilder] New agent builder
    def agent(type)
      Builders::AgentBuilder.new(type)
    end

    # Create a new team builder for multi-agent composition
    #
    # @example
    #   Smolagents.team
    #     .model { OpenAIModel.lm_studio("llama3") }
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research then write")
    #     .build
    #
    # @return [Builders::TeamBuilder] New team builder
    def team
      Builders::TeamBuilder.new
    end

    # Create a new model builder for composable model configuration
    #
    # @example Basic model
    #   Smolagents.model(:openai)
    #     .id("gpt-4")
    #     .api_key(ENV["OPENAI_API_KEY"])
    #     .build
    #
    # @example Local model with reliability features
    #   Smolagents.model(:lm_studio)
    #     .id("llama3")
    #     .with_health_check
    #     .with_retry(max_attempts: 3)
    #     .with_queue(timeout: 120)
    #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
    #     .on_failover { |event| log("Switched to #{event.to_model}") }
    #     .build
    #
    # @example Wrap existing model
    #   existing = OpenAIModel.new(model_id: "gpt-4", api_key: key)
    #   Smolagents.model(existing)
    #     .with_fallback { backup }
    #     .build
    #
    # @param type_or_model [Symbol, Model] Model type or existing model instance
    # @return [Builders::ModelBuilder] New model builder
    def model(type_or_model = :openai)
      Builders::ModelBuilder.new(type_or_model)
    end
  end
end
