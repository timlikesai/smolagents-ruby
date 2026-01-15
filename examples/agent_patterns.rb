#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent Patterns: Building agents with the fluent DSL
#
# This example demonstrates the various ways to construct agents
# using smolagents-ruby's expressive builder pattern.

require "smolagents"

# =============================================================================
# Basic Agent Building
# =============================================================================
#
# The simplest way to create an agent is with the fluent builder:

agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0") }
  .tools(:web_search)
  .build

# The builder pattern allows chaining configuration:

agent = Smolagents.agent(:tool)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-20b-mxfp4") }
  .tools(:duckduckgo_search, :wikipedia_search, :visit_webpage)
  .max_steps(15)
  .planning(interval: 3)
  .verbosity(:info)
  .build

# =============================================================================
# Agent Types
# =============================================================================
#
# CodeAgent writes Ruby code to accomplish tasks. Best for complex reasoning:

code_agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-120b-mxfp4") }
  .tools(:ruby_interpreter)
  .instructions("Always show your work step by step")
  .build

# ToolCallingAgent uses JSON tool calls. Better for smaller models:

tool_agent = Smolagents.agent(:tool)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0") }
  .tools(:web_search)
  .build

# =============================================================================
# Callback Registration
# =============================================================================
#
# Monitor agent execution with callbacks:

monitored_agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-20b-mxfp4") }
  .tools(:web_search)
  .on(:before_step) do |step_number:|
    puts "[Step #{step_number}] Starting..."
  end
  .on(:after_step) do |step:, monitor:|
    puts "[Step #{step.step_number}] Completed in #{monitor.duration.round(2)}s"
    puts "  Tools called: #{step.tool_calls&.map(&:name)&.join(', ') || 'none'}"
  end
  .on(:after_task) do |result:|
    puts "\nTask completed with state: #{result.state}"
    puts "Total steps: #{result.steps.count}"
  end
  .on(:on_tokens_tracked) do |usage:|
    puts "  Tokens: +#{usage.input_tokens} in, +#{usage.output_tokens} out"
  end
  .build

# =============================================================================
# Planning Agents
# =============================================================================
#
# Enable periodic planning for complex multi-step tasks:

planning_agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-120b-mxfp4") }
  .tools(:web_search, :visit_webpage, :ruby_interpreter)
  .max_steps(20)
  .planning(interval: 5)  # Re-plan every 5 steps
  .instructions(<<~INSTRUCTIONS)
    You are a thorough research assistant.
    Before taking action, consider the best approach.
    Cite sources when providing information.
  INSTRUCTIONS
  .build

# =============================================================================
# Immutable Configuration
# =============================================================================
#
# The builder is immutable - each method returns a new builder:

base_builder = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-20b-mxfp4") }

# Create variants without modifying the original:
research_agent = base_builder.tools(:web_search, :wikipedia_search).build
code_agent = base_builder.tools(:ruby_interpreter).max_steps(20).build

# =============================================================================
# Running Agents
# =============================================================================
#
# Execute tasks with the run method:

# result = agent.run("What are the key features of Ruby 4.0?")
# puts result.output
# puts "Completed in #{result.steps.count} steps"

# Streaming execution:
# agent.run("Analyze this data", stream: true).each do |step|
#   puts "Step #{step.step_number}: #{step.observations}"
# end

# Preserve memory across runs:
# agent.run("Remember this: X=42", reset: true)
# agent.run("What is X?", reset: false)  # Keeps context

# =============================================================================
# Example: Research Agent
# =============================================================================

research_agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-120b-mxfp4") }
  .tools(:duckduckgo_search, :visit_webpage)
  .max_steps(12)
  .planning(interval: 4)
  .instructions(<<~PROMPT)
    You are a research assistant. When given a topic:
    1. Search for relevant sources
    2. Visit the most promising pages
    3. Synthesize findings into a clear summary
    4. Always cite your sources
  PROMPT
  .on(:after_step) { |step:, monitor:| puts "Step #{step.step_number}: #{monitor.duration.round(1)}s" }
  .build

puts "Research agent configured with #{research_agent.tools.count} tools"
puts "Max steps: #{research_agent.max_steps}"
puts "Planning interval: #{research_agent.planning_interval}"

# Uncomment to run:
# result = research_agent.run("What are the main features of Ruby 4.0?")
# puts result.output
