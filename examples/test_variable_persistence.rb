#!/usr/bin/env ruby
# rubocop:disable all

# Test script to verify variable persistence between code blocks
#
# This demonstrates how agents can use `self.var = value` or `remember(:var, value)`
# to persist variables across multiple code executions within the same agent run.

require "bundler/setup"
require "smolagents"

puts "=" * 70
puts "TESTING VARIABLE PERSISTENCE"
puts "=" * 70

# Create executor
executor = Smolagents::Executors::LocalRuby.new

puts "\n--- Test 1: Using self.var = syntax ---"
# First code block: define a variable using self.var =
result1 = executor.execute('self.my_result = [1, 2, 3].sum', language: :ruby)
puts "Code 1: self.my_result = [1, 2, 3].sum"
puts "  Output: #{result1.output}"
puts "  Variables: #{executor.variables.inspect}"

# Second code block: access the persisted variable
result2 = executor.execute('my_result * 2', language: :ruby)
puts "Code 2: my_result * 2"
puts "  Output: #{result2.output}"
puts "  Success: #{result2.success?}"

if result2.output == 12
  puts "✓ Test 1 PASSED: Variable persisted via self.var = syntax"
else
  puts "✗ Test 1 FAILED: Expected 12, got #{result2.output}"
end

puts "\n--- Test 2: Using remember() helper ---"
executor2 = Smolagents::Executors::LocalRuby.new

# First code block: use remember helper
result3 = executor2.execute('remember(:data, { name: "test", count: 5 })', language: :ruby)
puts "Code 1: remember(:data, { name: 'test', count: 5 })"
puts "  Output: #{result3.output}"
puts "  Variables: #{executor2.variables.inspect}"

# Second code block: access the persisted variable
result4 = executor2.execute('data[:count] + 10', language: :ruby)
puts "Code 2: data[:count] + 10"
puts "  Output: #{result4.output}"
puts "  Success: #{result4.success?}"

if result4.output == 15
  puts "✓ Test 2 PASSED: Variable persisted via remember() helper"
else
  puts "✗ Test 2 FAILED: Expected 15, got #{result4.output}"
end

puts "\n--- Test 3: Local variables DON'T persist (expected behavior) ---"
executor3 = Smolagents::Executors::LocalRuby.new

# First code block: local variable (will NOT persist)
result5 = executor3.execute('local_var = 42', language: :ruby)
puts "Code 1: local_var = 42"
puts "  Output: #{result5.output}"
puts "  Variables: #{executor3.variables.inspect}"

# Second code block: try to access local variable
result6 = executor3.execute('local_var * 2', language: :ruby)
puts "Code 2: local_var * 2"
puts "  Output: #{result6.output}"
puts "  Error: #{result6.error&.to_s[0..100]}"

if result6.error
  puts "✓ Test 3 PASSED: Local variables correctly don't persist"
else
  puts "✗ Test 3 FAILED: Local variable unexpectedly persisted"
end

puts "\n--- Test 4: Multiple variables ---"
executor4 = Smolagents::Executors::LocalRuby.new

# Define multiple variables
executor4.execute(<<~RUBY, language: :ruby)
  self.a = 10
  self.b = 20
  self.c = 30
RUBY
puts "Defined: self.a = 10, self.b = 20, self.c = 30"
puts "  Variables: #{executor4.variables.inspect}"

# Access them in new code block
result7 = executor4.execute('a + b + c', language: :ruby)
puts "Code 2: a + b + c"
puts "  Output: #{result7.output}"

if result7.output == 60
  puts "✓ Test 4 PASSED: Multiple variables persisted"
else
  puts "✗ Test 4 FAILED: Expected 60, got #{result7.output}"
end

puts "\n--- Test 5: With tools ---"
class AddTool < Smolagents::Tool
  self.tool_name = "add"
  self.description = "Adds two numbers"
  self.inputs = {
    a: { type: "integer", description: "First number" },
    b: { type: "integer", description: "Second number" }
  }
  self.output_type = "integer"

  def execute(a:, b:)
    a + b
  end
end

executor5 = Smolagents::Executors::LocalRuby.new
executor5.send_tools("add" => AddTool.new)

# Store tool result
result8 = executor5.execute('self.sum = add(a: 5, b: 7)', language: :ruby)
puts "Code 1: self.sum = add(a: 5, b: 7)"
puts "  Output: #{result8.output}"
puts "  Variables: #{executor5.variables.inspect}"

# Use in calculation
result9 = executor5.execute('sum * 3', language: :ruby)
puts "Code 2: sum * 3"
puts "  Output: #{result9.output}"

if result9.output == 36
  puts "✓ Test 5 PASSED: Tool results persist"
else
  puts "✗ Test 5 FAILED: Expected 36, got #{result9.output}"
end

puts "\n" + "=" * 70
puts "SUMMARY"
puts "=" * 70
puts "Variable persistence works using:"
puts "  - self.var = value  # Setter method, persists"
puts "  - remember(:var, value)  # Helper method, persists"
puts "  - var = value  # Local variable, does NOT persist"
puts ""
puts "This allows agent models to store results between code blocks"
puts "within the same agent run."
