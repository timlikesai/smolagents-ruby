require "thor"
require_relative "model_builder"
require_relative "commands"

module Smolagents
  module CLI
    # Main CLI command class for smolagents.
    #
    # Provides a command-line interface for running agents with configurable models, tools,
    # and execution parameters. Built on Thor for command routing and option parsing.
    #
    # Includes mixins for model building and command implementations, allowing flexible
    # agent creation and execution through the command line.
    #
    # @example Run a task with GPT-4
    #   Smolagents::CLI::Main.start(["execute", "Find the capital of France", "--model", "gpt-4"])
    #
    # @example Run with custom provider and tools
    #   Smolagents::CLI::Main.start([
    #     "execute",
    #     "What's the weather?",
    #     "--provider", "anthropic",
    #     "--model", "claude-3-5-sonnet-20241022",
    #     "--tools", "duckduckgo_search", "final_answer"
    #   ])
    #
    # @example List available tools
    #   Smolagents::CLI::Main.start(["tools"])
    #
    # @example Show model provider examples
    #   Smolagents::CLI::Main.start(["models"])
    #
    # @see ModelBuilder
    # @see Commands
    class Main < Thor
      include ModelBuilder
      include Commands

      desc "execute TASK", "Run an agent with the given task"
      option :model, type: :string, default: "gpt-4", aliases: "-m", desc: "Model to use"
      option :provider, type: :string, default: "openai", aliases: "-p", desc: "Model provider (openai, anthropic)"
      option :tools, type: :array, default: %w[duckduckgo_search final_answer], aliases: "-t", desc: "Tools to enable"
      option :max_steps, type: :numeric, default: 10, aliases: "-s", desc: "Maximum reasoning steps"
      option :agent_type, type: :string, default: "tool_calling", aliases: "-a", desc: "Agent type (code, tool_calling)"
      option :image, type: :array, aliases: "-i", desc: "Image files to include"
      option :verbose, type: :boolean, default: false, aliases: "-v", desc: "Show detailed output"
      option :api_key, type: :string, desc: "API key (defaults to environment variable)"
      option :api_base, type: :string, desc: "Custom API base URL"
      # Executes an agent task with given question and options.
      #
      # Delegated to {Commands#run_task}. Accepts a task string and runs an agent
      # with the configured model, tools, and execution parameters.
      #
      # @param task [String] The task/question for the agent to answer
      # @return [void]
      #
      # @example Execute a simple task
      #   execute("What is 2 + 2?")
      #
      # @note Call via CLI: `smolagents execute "Your task here"`
      # @see Commands#run_task
      def execute(task) = run_task(task)

      desc "tools", "List available default tools"
      # Lists all available tools.
      #
      # Delegated to {Commands#tools}. Displays all tools in the registry with descriptions.
      #
      # @return [void]
      #
      # @example List tools
      #   list_tools
      #
      # @note Call via CLI: `smolagents tools`
      # @see Commands#tools
      def list_tools = tools

      desc "models", "Show model provider examples"
      # Shows model provider examples and configurations.
      #
      # Delegated to {Commands#models}. Displays supported providers and example
      # command-line configurations for different models.
      #
      # @return [void]
      #
      # @example Show models
      #   list_models
      #
      # @note Call via CLI: `smolagents models`
      # @see Commands#models
      def list_models = models

      desc "version", "Show version"
      # Displays the version of smolagents.
      #
      # Outputs the current version string using the VERSION constant.
      #
      # @return [void]
      #
      # @example Show version
      #   version
      #
      # @note Call via CLI: `smolagents version` or `smolagents --version`
      # @see Smolagents::VERSION
      def version = say("smolagents #{Smolagents::VERSION}")

      map %w[--version] => :version
      map "run" => :execute
      map "tools" => :list_tools
      map "models" => :list_models
    end
  end
end
