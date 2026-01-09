#!/usr/bin/env ruby
# frozen_string_literal: true

# Ruby-Native Features Examples
# Demonstrates idiomatic Ruby patterns for building agents with smolagents

require "smolagents"

# =============================================================================
# 1. DSL-Based Agent Definition
# =============================================================================

puts "=" * 80
puts "Example 1: DSL-Based Agent Definition"
puts "=" * 80

agent = Smolagents.define_agent do
  name "Ruby Research Assistant"
  description "Helps with Ruby programming research"

  use_model "gpt-4", provider: :openai
  agent_type :tool_calling
  max_steps 10

  # Define tools inline
  tool :calculate do
    description "Perform mathematical calculations"
    input :expression, type: :string, description: "Math expression to evaluate"
    output_type :number

    execute do |expression:|
      # Safe eval would go here
      eval(expression)
    end
  end

  # Use default tools
  tools :web_search, :final_answer

  # Register callbacks for monitoring
  on :step_complete do |step_name, monitor|
    puts "✓ #{step_name} completed in #{monitor.duration.round(2)}s"
  end

  on :tokens_tracked do |usage|
    puts "  Tokens: #{usage.input_tokens} in, #{usage.output_tokens} out"
  end
end

# =============================================================================
# 2. Global Configuration
# =============================================================================

puts "\n" + "=" * 80
puts "Example 2: Global Configuration"
puts "=" * 80

# Configure global defaults that apply to all agents
Smolagents.configure do |config|
  config.custom_instructions = "Always cite sources and be concise"
  config.max_steps = 15
  config.authorized_imports = ["json", "uri", "time"]
end

# Agents created after configuration inherit these defaults
agent_with_defaults = Smolagents::CodeAgent.new(
  tools: [Smolagents::FinalAnswerTool.new],
  model: Smolagents::OpenAIModel.new(model_id: "gpt-4")
)

puts "Agent max_steps: #{agent_with_defaults.max_steps}" # => 15
puts "System prompt includes: '#{agent_with_defaults.system_prompt[/Always cite sources.{0,30}/]}'"

# Per-agent overrides still work
agent_with_override = Smolagents::CodeAgent.new(
  tools: [Smolagents::FinalAnswerTool.new],
  model: Smolagents::OpenAIModel.new(model_id: "gpt-4"),
  custom_instructions: "Use technical jargon",
  max_steps: 25
)

puts "Overridden max_steps: #{agent_with_override.max_steps}" # => 25
puts "Overridden instructions include: '#{agent_with_override.system_prompt[/technical jargon/i]}'"

# Reset configuration when needed (useful for tests)
Smolagents.reset_configuration!
puts "Configuration reset to defaults"

# =============================================================================
# 3. Pattern Matching for Response Parsing
# =============================================================================

puts "\n" + "=" * 80
puts "Example 3: Pattern Matching"
puts "=" * 80

# Using pattern matching to handle different message types
def handle_message(message)
  case message
  in Smolagents::ChatMessage[role: :assistant, tool_calls: Array => calls]
    puts "Assistant wants to call #{calls.size} tools:"
    calls.each { |tc| puts "  - #{tc.name}(#{tc.arguments})" }

  in Smolagents::ChatMessage[role: :assistant, content: String => text] if text.include?("error")
    puts "Error response: #{text}"

  in Smolagents::ChatMessage[role: :assistant, content: String => text]
    puts "Assistant response: #{text}"

  in Smolagents::ChatMessage[role: :system]
    puts "System message (ignored)"

  else
    puts "Unknown message format"
  end
end

# Using pattern matching for error categorization
def handle_api_error(error)
  category = Smolagents::PatternMatching.categorize_error(error)

  case category
  in :rate_limit
    puts "Rate limited! Waiting before retry..."
    sleep 60

  in :timeout
    puts "Timeout! Reducing request size..."

  in :authentication
    puts "Auth failed! Check API keys..."

  else
    puts "Unknown error: #{error.message}"
  end
end

# =============================================================================
# 4. Concerns/Mixins for Custom Behavior
# =============================================================================

puts "\n" + "=" * 80
puts "Example 4: Using Concerns for Custom Agents"
puts "=" * 80

class CustomAgent
  include Smolagents::Concerns::Monitorable
  include Smolagents::Concerns::Retryable
  include Smolagents::Concerns::Streamable

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
  end

  def process_task(task)
    monitor_step(:task_processing, metadata: { task: task }) do |monitor|
      with_retry(max_attempts: 3, base_delay: 1.0) do
        # Simulate API call
        result = call_api(task)
        monitor.record_metric(:result_length, result.length)
        result
      end
    end
  end

  def call_api(task)
    "Processed: #{task}"
  end

  def process_with_streaming(tasks)
    stream do |yielder|
      tasks.each do |task|
        result = process_task(task)
        yielder << result
      end
    end
  end
end

custom = CustomAgent.new

# Register callbacks
custom.register_callback(:on_step_complete) do |step_name, monitor|
  puts "Step #{step_name} metrics: #{monitor.metrics}"
end

# Process with monitoring
result = custom.process_task("Test task")
puts "Result: #{result}"

# Process with streaming
custom.process_with_streaming(["Task 1", "Task 2", "Task 3"])
  .select { |r| r.include?("Task") }
  .map { |r| r.upcase }
  .each { |r| puts "  #{r}" }

# =============================================================================
# 5. Testing Utilities
# =============================================================================

puts "\n" + "=" * 80
puts "Example 5: Testing Utilities"
puts "=" * 80

# This would be in your RSpec tests:
puts "# In spec/my_agent_spec.rb:"
puts <<~RUBY
  require 'smolagents/testing'

  RSpec.describe MyAgent do
    include Smolagents::Testing::Helpers

    it "completes a task successfully" do
      # Mock a model that responds with specific text
      model = mock_model_that_responds("final_answer('Done')")

      # Create spy tool to track calls
      search_tool = spy_tool("search")

      # Build test agent
      agent = test_agent(
        model_response: "final_answer('Success')",
        tools: [search_tool]
      )

      # Run and verify
      result = agent.run("Test task")
      expect(result).to eq("Success")
      expect(search_tool).to be_called
      expect(search_tool.calls.first).to include(query: "test")
    end

    it "handles errors gracefully" do
      failing_tool = mock_tool("search", raises: AgentToolExecutionError.new("Failed"))
      agent = test_agent(tools: [failing_tool])

      expect { agent.run("Bad task") }.to raise_agent_error(AgentToolExecutionError)
    end
  end
RUBY

# =============================================================================
# 6. Streaming with Lazy Evaluation
# =============================================================================

puts "\n" + "=" * 80
puts "Example 6: Advanced Streaming"
puts "=" * 80

class StreamingAgent
  include Smolagents::Concerns::Streamable

  def run_with_pipeline(task, steps: 5)
    # Create a lazy stream of processing steps
    stream do |yielder|
      steps.times do |i|
        yielder << { step: i + 1, result: "Processing step #{i + 1}" }
        sleep 0.1 # Simulate work
      end
    end
    .select { |item| item[:step] > 2 }  # Skip first 2 steps
    .map { |item| item[:result].upcase }  # Transform
    .each { |item| puts "  → #{item}" }  # Display
  end

  def run_with_error_handling(items)
    safe_stream(on_error: :skip) do |yielder|
      items.each do |item|
        # This would normally fail on some items
        yielder << process_item(item)
      end
    end
  end

  def process_item(item)
    raise "Error!" if item == "bad"
    "Processed: #{item}"
  end
end

streaming = StreamingAgent.new
puts "\nLazy pipeline:"
streaming.run_with_pipeline("Demo task", steps: 5)

puts "\nError handling:"
streaming.run_with_error_handling(["good", "bad", "good"])
  .each { |r| puts "  #{r}" }

# =============================================================================
# 7. Quick Agent Creation
# =============================================================================

puts "\n" + "=" * 80
puts "Example 7: Quick Agent Creation"
puts "=" * 80

# One-liner agent creation
quick_agent = Smolagents.agent(
  model: "gpt-4",
  tools: [:web_search, :final_answer],
  max_steps: 5
)

puts "Created agent with:"
puts "  Model: #{quick_agent.model.model_id}"
puts "  Tools: #{quick_agent.tools.keys.join(', ')}"
puts "  Max steps: #{quick_agent.max_steps}"

# =============================================================================
# 8. Custom Tool with DSL
# =============================================================================

puts "\n" + "=" * 80
puts "Example 8: Custom Tool Definition"
puts "=" * 80

weather_tool = Smolagents.define_tool(:weather) do
  description "Get weather information for a location"

  inputs(
    location: { type: :string, description: "City name" },
    units: { type: :string, description: "Temperature units", nullable: true }
  )

  output_type :string

  execute do |location:, units: "celsius"|
    # Would call weather API here
    "Weather in #{location}: 20°#{units == 'fahrenheit' ? 'F' : 'C'}"
  end
end

puts "Tool: #{weather_tool.name}"
puts "Description: #{weather_tool.description}"
puts "Inputs: #{weather_tool.inputs.keys.join(', ')}"
puts "\nTest call:"
puts weather_tool.call(location: "Paris", units: "celsius")

# =============================================================================
# 9. Retry Strategies with Pattern Matching
# =============================================================================

puts "\n" + "=" * 80
puts "Example 9: Advanced Retry Strategies"
puts "=" * 80

class APIClient
  include Smolagents::Concerns::Retryable

  def call_with_smart_retry
    attempt = 0

    with_retry_strategy do |error, attempt_num|
      case [error, attempt_num]
      in [Faraday::TooManyRequestsError, 1..3]
        { retry: true, delay: 60.0 }  # Wait longer for rate limits

      in [Faraday::TimeoutError, 1..5]
        { retry: true, delay: 2.0 * attempt_num }  # Exponential for timeouts

      in [Faraday::ServerError, n] if n < 3
        { retry: true, delay: 5.0 }  # Quick retry for server errors

      else
        { retry: false }  # Give up
      end
    end
  end
end

puts "Retry strategy configured with pattern matching"
puts "- Rate limits: 60s wait, 3 attempts"
puts "- Timeouts: exponential backoff, 5 attempts"
puts "- Server errors: 5s wait, 3 attempts"

# =============================================================================
puts "\n" + "=" * 80
puts "Examples complete! Key takeaways:"
puts "=" * 80
puts <<~TAKEAWAYS

  1. DSL provides Ruby-native agent definition
  2. Pattern matching simplifies response handling
  3. Concerns/mixins enable code reuse
  4. Testing utilities make agent testing easy
  5. Streaming with lazy evaluation is memory-efficient
  6. Quick helpers for common patterns
  7. Custom tools are easy to define
  8. Retry strategies use pattern matching

  All examples work with pure Ruby - no Rails required!
TAKEAWAYS
