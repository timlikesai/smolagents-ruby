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
# The simplest agent is a tool-calling agent. It's the foundation - all
# other capabilities compose on top of it:

agent = Smolagents.agent
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:duckduckgo_search)
  .build

# That's it! A working agent with search capability.

# =============================================================================
# Adding Code Execution
# =============================================================================
#
# Use .with(:code) to enable Ruby code generation and execution:

agent = Smolagents.agent
  .with(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:ruby_interpreter)
  .build

# Code agents write Ruby to accomplish tasks. Best for complex reasoning
# and models with strong code generation.

# =============================================================================
# Specializations
# =============================================================================
#
# Specializations are composable capability bundles - tools + instructions
# that you can mix together:

# Research specialist - adds search tools and research-focused instructions
researcher = Smolagents.agent
  .with(:researcher)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .max_steps(15)
  .build

# Data analyst - adds code execution + data analysis tools
analyst = Smolagents.agent
  .with(:data_analyst)  # implies :code
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .build

# Compose multiple specializations:
research_analyst = Smolagents.agent
  .with(:researcher, :fact_checker)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .max_steps(20)
  .build

# =============================================================================
# Custom Specializations
# =============================================================================
#
# Register your own specializations:

Smolagents.specialization(:code_reviewer,
  tools: [:ruby_interpreter],
  instructions: <<~TEXT,
    You are a code review specialist. Your approach:
    1. Analyze the code structure and patterns
    2. Check for common issues and anti-patterns
    3. Suggest improvements with examples
    4. Rate code quality on readability, maintainability, performance
  TEXT
  requires: :code
)

reviewer = Smolagents.agent
  .with(:code_reviewer)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .build

# =============================================================================
# Event Handlers
# =============================================================================
#
# Monitor agent execution with callbacks:

monitored_agent = Smolagents.agent
  .with(:researcher)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .on(:before_step) do |step_number:|
    puts "Starting step #{step_number}"
  end
  .on(:after_step) do |step:, monitor:|
    puts "Step completed in #{monitor.duration.round(2)}s"
  end
  .on(:tool_call) do |tool_name:, args:|
    puts "  Calling #{tool_name}(#{args.inspect})"
  end
  .build

# =============================================================================
# Planning
# =============================================================================
#
# Enable periodic re-planning for complex tasks:

planning_agent = Smolagents.agent
  .with(:code, :researcher)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .planning(interval: 3)  # Re-plan every 3 steps
  .max_steps(20)
  .build

# =============================================================================
# Immutable Builders
# =============================================================================
#
# Builders are immutable - each method returns a new builder.
# This enables safe configuration reuse:

base_builder = Smolagents.agent
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .max_steps(10)

# Create variants without affecting the base
research_agent = base_builder.with(:researcher).build
analysis_agent = base_builder.with(:code, :data_analyst).build

# =============================================================================
# Production Configuration
# =============================================================================
#
# Freeze configurations for production to prevent accidental changes:

prod_builder = Smolagents.agent
  .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
  .with(:researcher)
  .max_steps(15)
  .freeze!

# This would raise FrozenError:
# prod_builder.max_steps(20)

# But you can still build agents from frozen configs:
agent = prod_builder.build
