# frozen_string_literal: true

require "thor"
require_relative "../smolagents"

module Smolagents
  # Command-line interface for smolagents.
  class CLI < Thor
    desc "run TASK", "Run an agent with the given task"
    option :model, type: :string, default: "gpt-4", aliases: "-m", desc: "Model to use"
    option :provider, type: :string, default: "openai", aliases: "-p", desc: "Model provider (openai, anthropic)"
    option :tools, type: :array, default: %w[web_search final_answer], aliases: "-t", desc: "Tools to enable"
    option :max_steps, type: :numeric, default: 10, aliases: "-s", desc: "Maximum reasoning steps"
    option :agent_type, type: :string, default: "tool_calling", aliases: "-a", desc: "Agent type (code, tool_calling)"
    option :image, type: :array, aliases: "-i", desc: "Image files to include"
    option :verbose, type: :boolean, default: false, aliases: "-v", desc: "Show detailed output"
    option :api_key, type: :string, desc: "API key (defaults to environment variable)"
    option :api_base, type: :string, desc: "Custom API base URL"
    def run_task(task)
      model = build_model(provider: options[:provider], model_id: options[:model],
                          api_key: options[:api_key], api_base: options[:api_base])
      tools = options[:tools].map { |n| DefaultTools.available.fetch(n) { raise Thor::Error, "Unknown tool: #{n}" }.new }
      agent_class = options[:agent_type] == "code" ? CodeAgent : ToolCallingAgent
      agent = agent_class.new(tools: tools, model: model, max_steps: options[:max_steps], logger: build_logger)

      say "Running agent...", :cyan
      result = agent.run(task, images: options[:image])

      if result.success?
        say "\nResult:", :green
        say result.output
        say "\n(#{result.steps.size} steps, #{result.timing.duration.round(2)}s)", :cyan
      else
        say "\nAgent did not complete successfully: #{result.state}", :red
        say "Last observation: #{result.steps.last&.observations&.slice(0, 200)}...", :yellow if result.steps.any?
      end
    end

    desc "tools", "List available default tools"
    def tools
      say "Available tools:", :cyan
      DefaultTools.available.each do |name, tool_class|
        say "\n  #{name}", :green
        say "    #{tool_class.new.description}"
      end
    end

    desc "models", "Show model provider examples"
    def models
      say "Model providers:", :cyan
      { "OpenAI" => ["--provider openai --model gpt-4", "--provider openai --model gpt-3.5-turbo"],
        "Anthropic" => ["--provider anthropic --model claude-3-5-sonnet-20241022"],
        "Local (LM Studio)" => ["--provider openai --model local-model --api-base http://localhost:1234/v1"],
        "Local (Ollama)" => ["--provider openai --model llama3 --api-base http://localhost:11434/v1"] }.each do |name, examples|
        say "\n  #{name}:", :green
        examples.each { |ex| say "    #{ex}" }
      end
    end

    desc "version", "Show version"
    def version = say("smolagents #{Smolagents::VERSION}")

    map %w[--version -v] => :version
    map "run" => :run_task

    private

    MODEL_BUILDERS = {
      openai: ->(opts) { require_relative "models/openai_model"; OpenAIModel.new(**opts) },
      anthropic: ->(opts) { require_relative "models/anthropic_model"; AnthropicModel.new(**opts) }
    }.freeze

    def build_model(provider:, model_id:, api_key:, api_base:)
      opts = { model_id: model_id }.tap { |o| o[:api_key] = api_key if api_key; o[:api_base] = api_base if api_base }
      MODEL_BUILDERS.fetch(provider.to_sym) { raise Thor::Error, "Unknown provider: #{provider}" }.call(opts)
    end

    def build_logger
      level = options[:verbose] ? Monitoring::AgentLogger::DEBUG : Monitoring::AgentLogger::WARN
      Monitoring::AgentLogger.new(output: $stderr, level: level)
    end
  end
end
