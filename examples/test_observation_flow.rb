#!/usr/bin/env ruby
# rubocop:disable all

# Test that demonstrates the observation flow in the agent loop
#
# This shows how the agent sees tool results and uses them in the next step.

require "bundler/setup"
require "smolagents"

puts "=" * 70
puts "TESTING OBSERVATION FLOW"
puts "=" * 70

# Simple search tool
class TestSearchTool < Smolagents::Tool
  self.tool_name = "search"
  self.description = "Search for information"
  self.inputs = { query: { type: "string", description: "Query" } }
  self.output_type = "array"

  def execute(query:)
    [
      { title: "Ruby 3.3 Release Notes", link: "https://ruby-lang.org/releases/3.3" },
      { title: "What's New in Ruby 3.3", link: "https://example.com/ruby33" }
    ]
  end
end

# Track what the model sees
observations_seen = []

model = Smolagents::Testing::MockModel.new

# Step 1: Model runs a search
model.queue_code_action('results = search(query: "Ruby 3.3")')

# Step 2: Model uses the observation to answer
model.queue_code_action('final_answer(answer: "The latest Ruby is 3.3 - see ruby-lang.org")')

# Create agent with event hooks to track observations
# Disable observation routing and evaluation for MockModel (they consume queue responses!)
agent = Smolagents.agent
  .model { model }
  .tools(TestSearchTool.new)
  .route_observations(enabled: false)
  .evaluation(enabled: false)
  .on(:step_complete) do |step, ctx|
    puts "\n[Step #{ctx.step_number}] Step complete: #{step.class.name}"
    puts "  methods: #{step.methods(false).sort.join(', ')}" if step.respond_to?(:methods)
    if step.respond_to?(:observations) && step.observations
      observations_seen << step.observations
      puts "  Observation received:"
      puts "  #{step.observations.to_s[0..200]}"
    end
    if step.respond_to?(:output) && step.output
      puts "  Output: #{step.output.to_s[0..100]}"
    end
  end
  .on(:error) do |error_class, error_message, context, recoverable|
    puts "\n[ERROR] #{error_class}: #{error_message}"
    puts "  Context: #{context}"
    puts "  Recoverable: #{recoverable}"
  end
  .build

puts "\n--- Checking routing_enabled ---"
# Debug: Check builder config before build
builder_after_route = Smolagents.agent
  .model { model }
  .tools(TestSearchTool.new)
  .route_observations(enabled: false)
puts "Builder config routing_enabled: #{builder_after_route.send(:configuration)[:routing_enabled]}"

runtime = agent.instance_variable_get(:@runtime)
puts "runtime @routing_enabled: #{runtime.instance_variable_get(:@routing_enabled)}"
puts "routing_enabled?: #{runtime.routing_enabled?}" if runtime.respond_to?(:routing_enabled?)

puts "\n--- Running agent ---"
begin
  result = agent.run("What's the latest Ruby version?")
rescue => e
  puts "Exception: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  result = nil
end

puts "\n--- Result ---"
if result
  puts "Output: #{result.output}"
  puts "Steps: #{result.steps&.length}"
  puts "State: #{result.state}"
  puts "Result class: #{result.class}"

  result.steps&.each_with_index do |step, i|
    puts "\n  Step #{i}: #{step.class.name}"
    puts "    #{step.to_h.inspect[0..200]}" if step.respond_to?(:to_h)
    if step.respond_to?(:error) && step.error
      puts "    ERROR: #{step.error}"
    end
    if step.respond_to?(:observations) && step.observations
      puts "    Observations (full):"
      puts step.observations.to_s.lines.map { |l| "      #{l}" }.join
    end
  end
else
  puts "No result returned"
end

puts "\n--- Observations the model saw ---"
puts "#{observations_seen.length} observations captured"
observations_seen.each_with_index do |obs, i|
  puts "\nObservation #{i + 1}:"
  puts obs.to_s[0..300]
end

puts "\n" + "=" * 70
puts "KEY INSIGHT:"
puts "=" * 70
puts "The agent loop works in steps:"
puts "1. Model generates code with tool calls"
puts "2. Code executes, tools return ToolFutures"
puts "3. Results resolve, observation is captured"
puts "4. Model sees observation and generates next step"
puts "5. Model can reference observed data in final_answer"
puts "\nVariables don't persist between steps - but observations do!"
