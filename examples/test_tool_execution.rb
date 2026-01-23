#!/usr/bin/env ruby
# frozen_string_literal: true

# Tool Execution Test Suite
#
# Tests the critical path: model generates code -> tools execute -> model uses results.
# Uses the fluent DSL to define and run tests - the same patterns as building agents.
#
# Usage:
#   ruby examples/test_tool_execution.rb                              # All tests
#   ruby examples/test_tool_execution.rb gemma-3n                     # Specific model
#   ruby examples/test_tool_execution.rb gemma-3n variable_persistence # Specific capability
#
# The fluent DSL:
#   Smolagents.test_suite(:my_tests)
#     .requires(:variable_persistence)
#     .requires(:sequential_tools)
#     .reliability(runs: 3, threshold: 0.67)
#     .run(model)

require "bundler/setup"
require "smolagents"
require "smolagents/testing"

# Parse arguments
model_id = ARGV[0] || ENV.fetch("MODEL_ID", "gemma-3n-e4b")
capability = ARGV[1]&.to_sym

puts "=" * 60
puts "TOOL EXECUTION TEST SUITE"
puts "=" * 60
puts "Model: #{model_id}"
puts "Testing: #{capability || 'all capabilities'}"
puts

# Show available capabilities
puts "Available capabilities:"
Smolagents::Testing::ToolExecutionTests::CAPABILITIES.each do |cap|
  tests = Smolagents::Testing::Capabilities.for_capability(cap)
  puts "  #{cap}: #{tests.map(&:name).join(', ')}"
end
puts

# Create model
model = Smolagents::OpenAIModel.lm_studio(model_id)

# Build test suite using the fluent DSL
suite = Smolagents.test_suite(:tool_execution)

if capability
  suite = suite.requires(capability)
else
  # Test all tool execution capabilities
  Smolagents::Testing::ToolExecutionTests::CAPABILITIES.each do |cap|
    suite = suite.requires(cap)
  end
end

# Configure reliability (multiple runs per test)
suite = suite.reliability(runs: 1, threshold: 0.5)

puts "Running #{suite.all_test_cases.size} tests..."
puts

# Run each test and collect results
results = []
suite.all_test_cases.each do |test_case|
  print "  #{test_case.name}... "
  $stdout.flush

  # Get the tools for this test
  tools = Smolagents::Testing::ToolExecutionTests.tools_for(test_case)

  # Build agent with the test's tools
  agent = Smolagents.agent
    .model { model }
    .tools(*tools)
    .max_steps(test_case.max_steps)
    .build

  # Run the test
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    run_result = agent.run(test_case.task)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    passed = test_case.validator&.call(run_result.output) || run_result.success?

    # Extract error from steps if any
    step_error = run_result.steps&.find { |s| s.respond_to?(:error) && s.error }&.error

    result = {
      name: test_case.name,
      capability: test_case.capability,
      passed:,
      output: run_result.output,
      steps: run_result.steps&.size || 0,
      duration:,
      error: run_result.error? ? (step_error || "error state") : nil
    }
  rescue StandardError => e
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    result = {
      name: test_case.name,
      capability: test_case.capability,
      passed: false,
      output: nil,
      steps: 0,
      duration:,
      error: e.message
    }
  end

  results << result

  if result[:passed]
    puts "PASS (#{result[:duration].round(2)}s, #{result[:steps]} steps)"
  else
    puts "FAIL"
    puts "    Output: #{result[:output].to_s[0..60]}..." if result[:output]
    puts "    Error: #{result[:error]}" if result[:error]
  end
end

# Summary
puts
puts "=" * 60
puts "RESULTS"
puts "=" * 60

passed = results.count { |r| r[:passed] }
total = results.size
pass_rate = total.positive? ? (passed.to_f / total * 100).round(1) : 0

puts "Pass Rate: #{passed}/#{total} (#{pass_rate}%)"
puts

# Group by capability
results.group_by { |r| r[:capability] }.each do |cap, cap_results|
  cap_passed = cap_results.count { |r| r[:passed] }
  status = cap_passed == cap_results.size ? "PASS" : "PARTIAL"
  puts "#{cap}: #{cap_passed}/#{cap_results.size} [#{status}]"
end

puts
puts "=" * 60

# Exit with appropriate code
exit(passed < total ? 1 : 0)
