#!/usr/bin/env ruby
# Quick test runner for tiered reasoning with real infrastructure
#
# Run: ruby experiments/multi_model_agents/run_tiered_test.rb

require_relative "../../lib/smolagents"
require_relative "04_tiered_reasoning"

puts "=" * 60
puts "TIERED REASONING AGENT - LIVE TEST"
puts "=" * 60
puts

# Step 1: Test health checks on each model factory
puts "Step 1: Testing model health..."
puts

begin
  puts "  Testing fast_20b on LLaMA Ultra..."
  fast = Experiments::TieredReasoning::Models.fast_20b.build
  health = fast.health_check
  puts "    Status: #{health.status}"
  puts "    Latency: #{health.latency_ms}ms" if health.latency_ms
  puts "    Model: #{health.model_id}" if health.model_id
  puts "    Error: #{health.error}" if health.error
rescue StandardError => e
  puts "    FAILED: #{e.class}: #{e.message}"
end
puts

begin
  puts "  Testing big_30b on LLaMA Ultra..."
  big = Experiments::TieredReasoning::Models.big_30b.build
  health = big.health_check
  puts "    Status: #{health.status}"
  puts "    Latency: #{health.latency_ms}ms" if health.latency_ms
  puts "    Model: #{health.model_id}" if health.model_id
  puts "    Error: #{health.error}" if health.error
rescue StandardError => e
  puts "    FAILED: #{e.class}: #{e.message}"
end
puts

# Step 2: Build the agent with error event capture
puts "Step 2: Building tiered agent..."
metrics = Experiments::TieredReasoning::MetricsCollector.new
errors_captured = []

# First build the fast model directly to test
puts "  Testing fast model generation..."
begin
  fast_model = Experiments::TieredReasoning::Models.fast_20b.build
  puts "    Fast model: #{fast_model.class.name} (#{fast_model.model_id})"

  # Try a direct generation using proper ChatMessage types
  test_msg = Smolagents::Types::ChatMessage.user("Say 'hello' and nothing else")
  response = fast_model.generate([test_msg])
  content = response.content.to_s
  puts "    Direct test response: #{content[0..100]}..."
rescue StandardError => e
  puts "    FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).map { "      #{it}" }.join("\n")
end

begin
  agent = Experiments::TieredReasoning.build_tiered_agent(metrics:)
  puts "  Agent built successfully!"
  puts
rescue StandardError => e
  puts "  FAILED to build agent: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

# Step 3: Run a simple task
puts "Step 3: Running simple task..."
puts "  Task: 'What is 2 + 2?'"
puts

begin
  result = agent.run("What is 2 + 2?")
  puts "  State: #{result.state}"
  puts "  Output: #{result.output.inspect}"
  puts "  Steps: #{result.steps.size}"
  result.steps.each_with_index do |step, i|
    puts "    Step #{i}: #{step.class.name.split("::").last}"
    if step.respond_to?(:error) && step.error
      puts "      Error: #{step.error}"
    end
    if step.respond_to?(:observations) && step.observations
      puts "      Observations: #{step.observations}"
    end
    if step.respond_to?(:model_output) && step.model_output
      puts "      Model output: #{step.model_output[0..200]}..."
    end
  end
rescue StandardError => e
  puts "  EXCEPTION: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { "    #{it}" }.join("\n")
end
puts

# Step 4: Show metrics
puts "Step 4: Metrics Summary"
puts "-" * 40
summary = metrics.summary
puts "  Total model calls: #{summary[:total_calls]}"
puts "  Calls by model: #{summary[:calls_by_model]}"
puts "  Failover count: #{summary[:failover_count]}"
puts "  Steps completed: #{summary[:steps_completed]}"
puts

puts "=" * 60
puts "TEST COMPLETE"
puts "=" * 60
