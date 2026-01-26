#!/usr/bin/env ruby
# Quick test runner for research swarm with real infrastructure
#
# Run: ruby experiments/multi_model_agents/run_research_swarm_test.rb

require_relative "../../lib/smolagents"
require_relative "05_research_swarm"

puts "=" * 60
puts "RESEARCH SWARM - LIVE TEST"
puts "=" * 60
puts

# Infrastructure endpoints
LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1".freeze
MAC_STUDIO = "http://mac-studio.reverse-bull.ts.net:1234/v1".freeze

# Build models with real infrastructure
def build_fast_model
  Smolagents.model(:openai)
            .base_url(LLAMA_ULTRA)
            .id("gpt-oss-20b-MXFP4")
            .timeout(60)
            .build
end

def build_coordinator_model
  # Coordinator can be fast - just orchestrating
  build_fast_model
end

def build_synthesizer_model
  # Synthesizer needs more capability for combining results
  Smolagents.model(:openai)
            .base_url(LLAMA_ULTRA)
            .id("Qwen3-Coder-30B-A3B-Instruct-MXFP4_MOE")
            .timeout(120)
            .build
end

# Step 1: Test model connectivity
puts "Step 1: Testing model connectivity..."
begin
  fast = build_fast_model
  test_msg = Smolagents::Types::ChatMessage.user("Say 'ready' and nothing else")
  response = fast.generate([test_msg])
  puts "  Fast model: #{response.content&.strip&.slice(0, 50)}..."
  puts "  Connection successful!"
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  exit 1
end
puts

# Step 2: Build the swarm
puts "Step 2: Building research swarm..."
begin
  swarm = Experiments::ResearchSwarm.build_swarm(
    coordinator_model: build_coordinator_model,
    researcher_model: build_fast_model,
    synthesizer_model: build_synthesizer_model
  )
  puts "  Team built: #{swarm[:team].class.name}"
  puts "  Tracker: #{swarm[:tracker].class.name}"
  puts "  Aggregator: #{swarm[:aggregator].class.name}"
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).map { "    #{it}" }.join("\n")
  exit 1
end
puts

# Step 3: Run a simple research query
puts "Step 3: Running research query..."
puts "  Query: 'What is the Ractor API in Ruby?'"
puts
puts "  (This may take a while with parallel researchers...)"
puts

begin
  result = swarm[:team].run("What is the Ractor API in Ruby?")
  puts "  State: #{result.state}"
  puts "  Steps: #{result.steps.size}"
  puts
  puts "  Output:"
  puts "  " + "-" * 50
  output_lines = result.output.to_s.split("\n")
  output_lines.first(20).each { |line| puts "  #{line}" }
  puts "  ..." if output_lines.size > 20
  puts "  " + "-" * 50
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { "    #{it}" }.join("\n")
end
puts

# Step 4: Show tracker stats
puts "Step 4: Swarm Tracker Summary"
puts "-" * 40
summary = swarm[:tracker].summary
puts "  Launched: #{summary[:launched]}"
puts "  Completed: #{summary[:completed]}"
puts "  Errors: #{summary[:errors]}"
puts "  Success rate: #{(summary[:success_rate] * 100).round(1)}%"
puts

puts "=" * 60
puts "TEST COMPLETE"
puts "=" * 60
