#!/usr/bin/env ruby
# rubocop:disable all

# Direct test of ToolFuture without the agent loop
#
# This tests the ToolFuture and batching at the executor level.

require "bundler/setup"
require "smolagents"

puts "=" * 70
puts "DIRECT TOOLFUTURE TEST"
puts "=" * 70

# Create a simple tool
class CounterTool < Smolagents::Tool
  self.tool_name = "count"
  self.description = "Returns a count"
  self.inputs = { start: { type: "integer", description: "Start value" } }
  self.output_type = "integer"

  @@call_log = []
  def self.call_log = @@call_log
  def self.reset! = @@call_log = []

  def execute(start:)
    @@call_log << { start:, time: Time.now.to_f }
    start * 2
  end
end

# Create executor and register tools
executor = Smolagents::Executors::LocalRuby.new
executor.send_tools("count" => CounterTool.new)

puts "\n--- Test: Multiple tool calls in one code block ---"
CounterTool.reset!

code = <<~RUBY
  # These should return ToolFutures immediately
  a = count(start: 1)
  b = count(start: 2)
  c = count(start: 3)

  # Access triggers resolution
  sum = a + b + c
  sum
RUBY

puts "Executing code:"
puts code.lines.map { |l| "  #{l}" }.join

result = executor.execute(code, language: :ruby)

puts "\nResult:"
puts "  output: #{result.output}"
puts "  error: #{result.error}"
puts "  is_final_answer: #{result.is_final_answer}"
puts "  logs: #{result.logs}"

puts "\nTool call log:"
CounterTool.call_log.each_with_index do |call, i|
  puts "  #{i + 1}. count(start: #{call[:start]}) at #{call[:time]}"
end

puts "\nExecutor tracked calls:"
executor.tool_calls.each_with_index do |tc, i|
  puts "  #{i + 1}. #{tc.tool_name}(#{tc.arguments}) => #{tc.result} (#{tc.duration.round(4)}s)"
end

puts "\n--- Verification ---"
expected_output = (1*2) + (2*2) + (3*2)  # 2 + 4 + 6 = 12
actual_output = result.output
puts "Expected: #{expected_output}"
puts "Actual: #{actual_output}"

if actual_output == expected_output && CounterTool.call_log.length == 3
  puts "✓ SUCCESS: ToolFutures work correctly!"
  puts "  - 3 tool calls were made"
  puts "  - Results were properly resolved"
  puts "  - Math operations work on resolved values"
else
  puts "✗ FAILED"
  puts "  - Expected output #{expected_output}, got #{actual_output}"
  puts "  - Expected 3 calls, got #{CounterTool.call_log.length}"
end
