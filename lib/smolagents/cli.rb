# frozen_string_literal: true

require "thor"
require_relative "../smolagents"

module Smolagents
  # Command-line interface for smolagents.
  # Provides commands to run agents, list tools, and more.
  #
  # @example Run an agent
  #   $ smolagents run "Search for Ruby news" --model gpt-4
  #
  # @example List available tools
  #   $ smolagents tools
  #
  # @example Show version
  #   $ smolagents version
  class CLI < Thor
    desc "run TASK", "Run an agent with the given task"
    long_desc <<~LONG_DESC
      Run an AI agent to complete a task.

      The agent will use the specified model and tools to complete the task.
      By default, uses ToolCallingAgent which is more reliable for smaller models.

      Examples:

        $ smolagents run "What is the capital of France?"

        $ smolagents run "Search for Ruby news" --model gpt-4 --tools web_search

        $ smolagents run "Analyze this image" --model gpt-4-vision --image photo.jpg
    LONG_DESC
    option :model, type: :string, default: "gpt-4", aliases: "-m",
           desc: "Model to use (e.g., gpt-4, claude-3-5-sonnet-20241022)"
    option :provider, type: :string, default: "openai", aliases: "-p",
           desc: "Model provider (openai, anthropic)"
    option :tools, type: :array, default: ["web_search", "final_answer"], aliases: "-t",
           desc: "Tools to enable (e.g., web_search, visit_webpage)"
    option :max_steps, type: :numeric, default: 10, aliases: "-s",
           desc: "Maximum reasoning steps"
    option :agent_type, type: :string, default: "tool_calling", aliases: "-a",
           desc: "Agent type (code, tool_calling)"
    option :image, type: :array, aliases: "-i",
           desc: "Image files to include with the task"
    option :verbose, type: :boolean, default: false, aliases: "-v",
           desc: "Show detailed output"
    option :api_key, type: :string,
           desc: "API key (defaults to environment variable)"
    option :api_base, type: :string,
           desc: "Custom API base URL (for local models)"
    def run_task(task)
      # Build model
      model = build_model(
        provider: options[:provider],
        model_id: options[:model],
        api_key: options[:api_key],
        api_base: options[:api_base]
      )

      # Build tools
      tools = build_tools(options[:tools])

      # Build agent
      agent_class = options[:agent_type] == "code" ? CodeAgent : ToolCallingAgent
      agent = agent_class.new(
        tools: tools,
        model: model,
        max_steps: options[:max_steps],
        logger: build_logger(options[:verbose])
      )

      # Run agent
      say "Running agent...", :cyan
      result = agent.run(task, images: options[:image])

      # Display result
      if result.success?
        say "\nResult:", :green
        say result.output
        say "\n(#{result.steps.size} steps, #{result.timing.duration.round(2)}s)", :cyan
      else
        say "\nAgent did not complete successfully: #{result.state}", :red
        if result.steps.any?
          last_step = result.steps.last
          say "Last observation: #{last_step.observations&.slice(0, 200)}...", :yellow if last_step.respond_to?(:observations)
        end
      end
    end

    desc "tools", "List available default tools"
    def tools
      say "Available tools:", :cyan
      say ""

      DefaultTools.available.each do |name, tool_class|
        tool = tool_class.new
        say "  #{name}", :green
        say "    #{tool.description}"
        say ""
      end
    end

    desc "models", "Show model provider examples"
    def models
      say "Model providers:", :cyan
      say ""

      say "  OpenAI:", :green
      say "    --provider openai --model gpt-4"
      say "    --provider openai --model gpt-3.5-turbo"
      say ""

      say "  Anthropic:", :green
      say "    --provider anthropic --model claude-3-5-sonnet-20241022"
      say "    --provider anthropic --model claude-3-opus-20240229"
      say ""

      say "  Local (LM Studio):", :green
      say "    --provider openai --model local-model --api-base http://localhost:1234/v1"
      say ""

      say "  Local (Ollama):", :green
      say "    --provider openai --model llama3 --api-base http://localhost:11434/v1"
    end

    desc "version", "Show version"
    def version
      say "smolagents #{Smolagents::VERSION}"
    end

    map %w[--version -v] => :version
    map "run" => :run_task

    private

    def build_model(provider:, model_id:, api_key:, api_base:)
      case provider.to_sym
      when :openai
        require_relative "models/openai_model"
        opts = { model_id: model_id }
        opts[:api_key] = api_key if api_key
        opts[:api_base] = api_base if api_base
        OpenAIModel.new(**opts)
      when :anthropic
        require_relative "models/anthropic_model"
        opts = { model_id: model_id }
        opts[:api_key] = api_key if api_key
        AnthropicModel.new(**opts)
      else
        raise Thor::Error, "Unknown provider: #{provider}"
      end
    end

    def build_tools(tool_names)
      tool_names.map do |name|
        tool_class = DefaultTools.available[name.to_s]
        raise Thor::Error, "Unknown tool: #{name}" unless tool_class

        tool_class.new
      end
    end

    def build_logger(verbose)
      level = verbose ? Monitoring::AgentLogger::DEBUG : Monitoring::AgentLogger::WARN
      Monitoring::AgentLogger.new(output: $stderr, level: level)
    end
  end
end
