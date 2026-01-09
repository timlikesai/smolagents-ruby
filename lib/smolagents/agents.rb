# frozen_string_literal: true

require_relative "agents/multi_step_agent"
require_relative "agents/managed_agent_tool"
require_relative "agents/code_agent"
require_relative "agents/tool_calling_agent"

module Smolagents
  # Agents module provides AI agents that can solve tasks using tools.
  #
  # Available agents:
  # - {MultiStepAgent} - Base class for multi-step reasoning agents
  # - {CodeAgent} - Generates and executes Ruby code
  # - {ToolCallingAgent} - Uses JSON tool calling format
  #
  # @example Using CodeAgent
  #   agent = Smolagents::CodeAgent.new(
  #     tools: [WebSearchTool.new, FinalAnswerTool.new],
  #     model: Smolagents::OpenAIModel.new(model_id: "gpt-4")
  #   )
  #   result = agent.run("What is the capital of France?")
  #   puts result.output # => "Paris"
  #
  # @example Using ToolCallingAgent
  #   agent = Smolagents::ToolCallingAgent.new(
  #     tools: [WebSearchTool.new, FinalAnswerTool.new],
  #     model: Smolagents::OpenAIModel.new(model_id: "gpt-4")
  #   )
  #   result = agent.run("Search for Ruby news")
  #
  # @example With callbacks
  #   agent = Smolagents::CodeAgent.new(tools: tools, model: model)
  #   agent.register_callback(:step_complete) do |step, monitor|
  #     puts "Step #{step.step_number} completed in #{monitor.duration}s"
  #   end
  #   result = agent.run(task)
  module Agents
  end
end
