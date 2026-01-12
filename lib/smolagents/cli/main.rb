# frozen_string_literal: true

require "thor"
require_relative "model_builder"
require_relative "commands"

module Smolagents
  module CLI
    class Main < Thor
      include ModelBuilder
      include Commands

      desc "run TASK", "Run an agent with the given task"
      option :model, type: :string, default: "gpt-4", aliases: "-m", desc: "Model to use"
      option :provider, type: :string, default: "openai", aliases: "-p", desc: "Model provider (openai, anthropic)"
      option :tools, type: :array, default: %w[duckduckgo_search final_answer], aliases: "-t", desc: "Tools to enable"
      option :max_steps, type: :numeric, default: 10, aliases: "-s", desc: "Maximum reasoning steps"
      option :agent_type, type: :string, default: "tool_calling", aliases: "-a", desc: "Agent type (code, tool_calling)"
      option :image, type: :array, aliases: "-i", desc: "Image files to include"
      option :verbose, type: :boolean, default: false, aliases: "-v", desc: "Show detailed output"
      option :api_key, type: :string, desc: "API key (defaults to environment variable)"
      option :api_base, type: :string, desc: "Custom API base URL"
      def run(task) = run_task(task)

      desc "tools", "List available default tools"
      def list_tools = tools

      desc "models", "Show model provider examples"
      def list_models = models

      desc "version", "Show version"
      def version = say("smolagents #{Smolagents::VERSION}")

      map %w[--version] => :version
      map "tools" => :list_tools
      map "models" => :list_models
    end
  end
end
