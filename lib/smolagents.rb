# frozen_string_literal: true

require_relative "smolagents/version"
require_relative "smolagents/errors"
require_relative "smolagents/data_types"
require_relative "smolagents/message_role"
require_relative "smolagents/chat_message"
require_relative "smolagents/memory"
require_relative "smolagents/tools/tool"
require_relative "smolagents/tools/tool_dsl"
require_relative "smolagents/tools/tool_collection"
require_relative "smolagents/tool_result"
require_relative "smolagents/lazy_tool_result"
require_relative "smolagents/tool_pipeline"
require_relative "smolagents/refinements"

# Concerns (mixins for shared behavior) - must be loaded before default_tools
require_relative "smolagents/concerns/http_client"
require_relative "smolagents/concerns/search_result_formatter"

require_relative "smolagents/default_tools"

# Concerns (mixins for shared behavior)
require_relative "smolagents/concerns/message_formatting"
require_relative "smolagents/concerns/retryable"
require_relative "smolagents/concerns/monitorable"
require_relative "smolagents/concerns/streamable"

# Pattern matching and DSL utilities
require_relative "smolagents/pattern_matching"
require_relative "smolagents/template_renderer"
require_relative "smolagents/prompt_sanitizer"
require_relative "smolagents/configuration"
require_relative "smolagents/dsl"

# Executors (code execution in multiple languages)
require_relative "smolagents/executors"

# Monitoring (callbacks and logging)
require_relative "smolagents/monitoring"

# Models (base class + lazy-loaded implementations)
require_relative "smolagents/models/model"
# Concrete models are lazy-loaded to avoid gem dependencies:
#   require 'smolagents/models/openai_model'
#   require 'smolagents/models/anthropic_model'

# Agents (multi-step reasoning agents)
require_relative "smolagents/agents"

# Main module for the smolagents library.
# This is a Ruby port of HuggingFace's smolagents Python library.
#
# Smolagents allows you to build AI agents that solve tasks by writing
# and executing code (CodeAgent) or by making tool calls (ToolCallingAgent).
#
# @example Basic agent usage (traditional)
#   model = Smolagents::OpenAIModel.new(model_id: "gpt-4")
#   tools = [Smolagents::DefaultTools::WebSearchTool.new]
#   agent = Smolagents::ToolCallingAgent.new(tools: tools, model: model)
#   result = agent.run("What is the capital of France?")
#
# @example Using DSL (Ruby-native)
#   agent = Smolagents.define_agent do
#     use_model "gpt-4"
#     tools :web_search, :final_answer
#     max_steps 10
#
#     on :step_complete do |step_name, monitor|
#       puts "Completed: #{step_name}"
#     end
#   end
#   result = agent.run("What is the capital of France?")
#
# @example Quick agent creation
#   agent = Smolagents.agent(model: "gpt-4", tools: [:web_search])
#   result = agent.run("Search for Ruby news")
#
# @see https://github.com/huggingface/smolagents
module Smolagents
  class Error < StandardError; end
end
