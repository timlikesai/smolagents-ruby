# Example: Testing with MockModel
#
# MockModel enables deterministic, fast agent testing without real LLMs.
# This is the foundation for reliable CI/CD and TDD with agents.
#
# Run: ruby examples/testing/01_mock_model.rb
# Test: bundle exec rspec spec/examples/testing/01_mock_model_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC MOCKMODEL USAGE
# =============================================================================
#
# MockModel queues responses that are returned in FIFO order.
# Use queue_final_answer for simple completion tests.

def test_simple_answer?
  model = Smolagents::Testing::MockModel.new
  model.queue_final_answer("Paris")

  agent = Smolagents.agent.model { model }.build
  result = agent.run("What is the capital of France?")

  result.output == "Paris"
end

# =============================================================================
# TESTING TOOL EXECUTION
# =============================================================================
#
# When testing tools, embed the tool call in final_answer for single-step tests.
# The tool executes and its result becomes the answer.

def test_tool_execution(model)
  agent = Smolagents.agent
                    .model { model }
                    .tool(:add, "Add two numbers", a: Integer, b: Integer) { |a:, b:| a + b }
                    .build

  agent.run("Add 10 and 32")
end

# =============================================================================
# CHAINED TOOL CALLS
# =============================================================================
#
# For tests involving multiple tools, nest calls in a single expression.
# This avoids the complexity of evaluation phases between steps.
#
# Instead of:   data = fetch(id: 42); format(data: data)
# Use:          format(data: fetch(id: 42))

def test_multi_step(model)
  agent = Smolagents.agent
                    .model { model }
                    .tool(:fetch, "Fetch data", id: Integer) { |id:| { id:, name: "Item #{id}" } }
                    .tool(:format, "Format data", data: Hash) { |data:| "Name: #{data[:name]}" }
                    .build

  agent.run("Fetch item 42 and format it")
end

# =============================================================================
# VERIFYING MODEL INTERACTIONS
# =============================================================================
#
# MockModel records all calls for verification:
# - model.calls - all call records
# - model.call_count - number of generate() calls
# - model.last_call - most recent call
# - model.be_exhausted (matcher) - all responses consumed

def verify_model_was_called(model)
  {
    total_calls: model.call_count,
    messages_in_first_call: model.calls.first&.messages&.size,
    remaining_responses: model.remaining_responses
  }
end

# =============================================================================
# TESTING ERROR HANDLING
# =============================================================================
#
# Test how agents handle errors by queueing code that will fail.

def test_error_recovery(model)
  agent = Smolagents.agent.model { model }.build
  agent.run("Test error handling")
end

# =============================================================================
# HELPER METHODS
# =============================================================================
#
# Use Smolagents::Testing::Helpers::ModelHelpers for common patterns.
#
# Available helpers:
#   mock_model { |m| ... }           - Create and configure MockModel
#   mock_model_for_single_step(ans)  - Quick single-answer setup
#   mock_model_with_planning(...)    - Planning scenario setup

# In RSpec, include at the describe block level:
#
#   RSpec.describe "MyAgent" do
#     include Smolagents::Testing::Helpers::ModelHelpers
#
#     it "works" do
#       model = mock_model { |m| m.queue_final_answer("done") }
#       # or: mock_model_for_single_step("42")
#     end
#   end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Testing Examples - Run the spec file for deterministic tests:"
  puts ""
  puts "  bundle exec rspec spec/examples/testing/01_mock_model_spec.rb"
  puts ""
  puts "Key patterns:"
  puts "  - queue_final_answer(value)     # Simple completion"
  puts "  - queue_code_action(code)       # Execute Ruby code"
  puts "  - queue_evaluation_continue     # Continue after step"
  puts "  - model.be_exhausted            # Verify all used"
end
