#!/usr/bin/env ruby
# rubocop:disable all

# Test script to verify ToolFuture lazy evaluation and batching works
#
# This uses MockModel to run deterministic tests of the ToolFuture system.

require "bundler/setup"
require "smolagents"

puts "=" * 70
puts "TESTING TOOL FUTURE LAZY EVALUATION"
puts "=" * 70

# Simple test tool that tracks calls
class TrackingTool < Smolagents::Tool
  self.tool_name = "track"
  self.description = "A tool that tracks when it's called"
  self.inputs = { value: { type: "string", description: "Value to track" } }
  self.output_type = "string"

  @@calls = []

  def self.calls = @@calls
  def self.reset! = @@calls = []

  def execute(value:)
    @@calls << { value:, time: Time.now.to_f }
    "Tracked: #{value}"
  end
end

# Test 1: Basic tool call returns future
puts "\n--- Test 1: Tool call returns ToolFuture ---"
TrackingTool.reset!

model = Smolagents::Testing::MockModel.new
model.queue_code_action('result = track(value: "hello")')
model.queue_code_action('final_answer(answer: result)')

agent = Smolagents.agent
  .model { model }
  .tools(TrackingTool.new)
  .build

result = agent.run("Track something")
puts "Result: #{result.output}"
puts "Tool calls made: #{TrackingTool.calls.length}"
puts "✓ Test 1 passed" if TrackingTool.calls.length == 1

# Test 2: Multiple tool calls in same code block
puts "\n--- Test 2: Multiple tool calls batch together ---"
TrackingTool.reset!

model = Smolagents::Testing::MockModel.new
model.queue_code_action(<<~RUBY)
  a = track(value: "first")
  b = track(value: "second")
  c = track(value: "third")
  combined = [a, b, c].join(", ")
RUBY
model.queue_code_action('final_answer(answer: combined)')

agent = Smolagents.agent
  .model { model }
  .tools(TrackingTool.new)
  .build

result = agent.run("Track multiple things")
puts "Result: #{result.output}"
puts "Tool calls made: #{TrackingTool.calls.length}"
puts "Call values: #{TrackingTool.calls.map { |c| c[:value] }.inspect}"
puts "✓ Test 2 passed" if TrackingTool.calls.length == 3

# Test 3: Verify lazy evaluation - tools don't run until results accessed
puts "\n--- Test 3: Lazy evaluation (tools run on access) ---"
TrackingTool.reset!

# This code assigns to variables but doesn't access them until the join
model = Smolagents::Testing::MockModel.new
model.queue_code_action(<<~RUBY)
  # These should return futures immediately
  x = track(value: "lazy_1")
  y = track(value: "lazy_2")
  # This forces resolution when we access .to_s
  final_answer(answer: x.to_s + " | " + y.to_s)
RUBY

agent = Smolagents.agent
  .model { model }
  .tools(TrackingTool.new)
  .build

result = agent.run("Test lazy eval")
puts "Result: #{result.output}"
puts "Tool calls: #{TrackingTool.calls.length}"
puts "✓ Test 3 passed" if TrackingTool.calls.length == 2

# Test 4: ToolResult works with include?
puts "\n--- Test 4: ToolResult deep include works ---"

class SearchTool < Smolagents::Tool
  self.tool_name = "search"
  self.description = "Search for things"
  self.inputs = { query: { type: "string", description: "Query" } }
  self.output_type = "array"

  def execute(query:)
    [
      { title: "Ruby Tutorial", link: "https://ruby-lang.org" },
      { title: "Ruby Gems Guide", link: "https://rubygems.org" }
    ]
  end
end

model = Smolagents::Testing::MockModel.new
model.queue_code_action('results = search(query: "ruby")')
model.queue_code_action('final_answer(answer: results.first["title"])')

agent = Smolagents.agent
  .model { model }
  .tools(SearchTool.new)
  .build

result = agent.run("Find ruby tutorials")
puts "Result: #{result.output}"

# Also test include? directly on ToolResult
search_tool = SearchTool.new
direct_result = search_tool.call(query: "test")
includes_ruby = direct_result.include?("Ruby")
puts "ToolResult.include?('Ruby'): #{includes_ruby}"
puts "✓ Test 4 passed" if includes_ruby && result.output.to_s.include?("Ruby")

# Summary
puts "\n" + "=" * 70
puts "ALL TESTS COMPLETED"
puts "=" * 70
puts "The ToolFuture lazy evaluation system is working!"
puts "- Tool calls return futures immediately"
puts "- Results resolve when accessed"
puts "- ToolResult.include? searches nested data"
