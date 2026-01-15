#!/usr/bin/env ruby
# frozen_string_literal: true

# Fiber Execution: Step-by-step control over agent execution
#
# This example demonstrates the Fiber execution model where you can:
# - Observe each step as it happens
# - Handle control requests interactively
# - Build custom UIs around agent execution
#
# Fibers provide bidirectional communication between your code and the agent,
# allowing you to pause, inspect, and respond to events during execution.

require "smolagents"

# =============================================================================
# Basic Fiber Execution
# =============================================================================
#
# The simplest fiber pattern: resume until we get a final result.

def basic_fiber_example
  puts "=" * 60
  puts "Basic Fiber Execution"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .max_steps(5)
    .build

  fiber = agent.run_fiber("What is 2 + 2?")

  loop do
    result = fiber.resume

    case result
    in Smolagents::Types::ActionStep => step
      puts "Step #{step.step_number}: #{step.observations&.slice(0, 80)}..."
    in Smolagents::Types::RunResult => final
      puts "Final answer: #{final.output}"
      break
    end
  end
end

# =============================================================================
# Step-by-Step Inspection
# =============================================================================
#
# Inspect each step in detail, useful for debugging and logging.

def detailed_step_inspection
  puts "\n" + "=" * 60
  puts "Detailed Step Inspection"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(:web_search)
    .max_steps(10)
    .build

  fiber = agent.run_fiber("What is the latest version of Ruby?")

  loop do
    result = fiber.resume

    case result
    in Smolagents::Types::ActionStep => step
      puts "\n--- Step #{step.step_number} ---"
      puts "Tool calls: #{step.tool_calls&.map(&:name)&.join(', ') || 'none'}"
      puts "Observations: #{step.observations&.slice(0, 200)}..." if step.observations
      puts "Has error: #{!step.error.nil?}"
      puts "Final answer: #{step.is_final_answer}"
      puts "Token usage: #{step.token_usage&.total_tokens || 'unknown'} tokens"

    in Smolagents::Types::RunResult => final
      puts "\n=== Run Complete ==="
      puts "State: #{final.state}"
      puts "Output: #{final.output}"
      puts "Total steps: #{final.step_count}"
      puts "Total tokens: #{final.token_usage&.total_tokens}"
      puts "Duration: #{final.duration&.round(2)}s"
      break
    end
  end
end

# =============================================================================
# Progress Tracking UI
# =============================================================================
#
# Build a simple progress tracker that shows execution status.

def progress_tracking_ui
  puts "\n" + "=" * 60
  puts "Progress Tracking UI"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(:web_search, :visit_webpage)
    .max_steps(8)
    .build

  fiber = agent.run_fiber("Find information about Ruby 4.0 features")

  steps_completed = 0
  max_steps = 8

  loop do
    result = fiber.resume

    case result
    in Smolagents::Types::ActionStep => step
      steps_completed = step.step_number
      progress = (steps_completed.to_f / max_steps * 100).round(0)
      bar = "#" * (progress / 5) + "-" * (20 - progress / 5)

      # Clear line and print progress
      print "\r[#{bar}] #{progress}% - Step #{steps_completed}/#{max_steps}"
      print " (#{step.tool_calls&.first&.name || 'thinking'})"
      $stdout.flush

    in Smolagents::Types::RunResult => final
      puts "\n\nComplete!"
      puts "Result: #{final.output&.slice(0, 200)}..."
      break
    end
  end
end

# =============================================================================
# Conditional Execution
# =============================================================================
#
# Stop early based on step content or external conditions.

def conditional_execution
  puts "\n" + "=" * 60
  puts "Conditional Execution (Stop Early)"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(:web_search)
    .max_steps(15)
    .build

  fiber = agent.run_fiber("Search for Ruby frameworks and list the top 5")

  found_results = false

  loop do
    result = fiber.resume

    case result
    in Smolagents::Types::ActionStep => step
      puts "Step #{step.step_number}"

      # Check if we have search results
      if step.observations&.include?("results")
        found_results = true
        puts "  Found search results!"
      end

      # Example: stop if we've found what we need and taken 3+ steps
      if found_results && step.step_number >= 3
        puts "\nStopping early - we have enough information"
        puts "Last observation: #{step.observations&.slice(0, 200)}..."
        break
      end

    in Smolagents::Types::RunResult => final
      puts "\nAgent finished naturally"
      puts "Output: #{final.output}"
      break
    end
  end
end

# =============================================================================
# Collecting All Steps
# =============================================================================
#
# Gather all steps for post-hoc analysis or replay.

def collect_all_steps
  puts "\n" + "=" * 60
  puts "Collecting All Steps for Analysis"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .max_steps(5)
    .build

  fiber = agent.run_fiber("Explain the difference between puts and print in Ruby")

  all_steps = []
  final_result = nil

  loop do
    result = fiber.resume

    case result
    in Smolagents::Types::ActionStep => step
      all_steps << step
    in Smolagents::Types::RunResult => final
      final_result = final
      break
    end
  end

  # Analyze collected steps
  puts "Collected #{all_steps.size} steps:"
  all_steps.each do |step|
    puts "  Step #{step.step_number}:"
    puts "    - Tools: #{step.tool_calls&.map(&:name)&.join(', ') || 'none'}"
    puts "    - Tokens: #{step.token_usage&.total_tokens || 'unknown'}"
  end

  puts "\nFinal result: #{final_result&.output&.slice(0, 100)}..."
end

# =============================================================================
# Run Examples
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Smolagents Fiber Execution Examples"
  puts "===================================\n"

  # Comment out examples you don't want to run
  # (they require API keys and make real requests)

  begin
    basic_fiber_example
    # detailed_step_inspection
    # progress_tracking_ui
    # conditional_execution
    # collect_all_steps
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts "(Make sure you have OPENAI_API_KEY set)"
  end
end
