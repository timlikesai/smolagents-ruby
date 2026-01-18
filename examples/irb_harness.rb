#!/usr/bin/env ruby
# rubocop:disable all

# IRB Harness for Agent Debugging
#
# Load this in IRB for interactive debugging:
#   require_relative 'examples/irb_harness'
#
# Then use:
#   run("your task")                    # Run with default agent
#   run("task", model: "other-model")   # Run with different model
#   last_run                            # Inspect last run details
#   last_run.code                       # See generated code
#   last_run.tools                      # See tool calls
#   last_run.errors                     # See errors
#   replay                              # Re-run same task

require "smolagents"

# Run Capture - Stores everything from a single run
RunCapture = Data.define(
  :task, :result, :steps, :tool_calls, :code_blocks, :errors,
  :start_time, :end_time, :model_id
) do
  def duration = end_time - start_time
  def success? = result&.success?
  def output = result&.output
  def step_count = steps.count
  def code = code_blocks.join("\n---\n")
  def tools = tool_calls
  def failed_tools = tool_calls.select { |t| t[:error] }

  def summary
    puts "Task: #{task}"
    puts "Model: #{model_id}"
    puts "Duration: #{duration.round(2)}s"
    puts "Steps: #{step_count}"
    puts "Tools: #{tool_calls.count} calls (#{failed_tools.count} failed)"
    puts "Errors: #{errors.count}"
    puts "Status: #{result&.state || "unknown"}"
    puts "Output: #{output&.to_s&.slice(0, 100)}#{"..." if output.to_s.length > 100}"
  end

  def show_code
    code_blocks.each_with_index do |block, i|
      puts "\n--- Step #{i + 1} ---"
      puts block
    end
  end

  def show_tools
    tool_calls.each_with_index do |tc, i|
      status = tc[:error] ? "FAILED" : "OK"
      puts "#{i + 1}. #{tc[:name]} [#{status}]"
      puts "   Args: #{tc[:args].inspect}"
      puts "   Result: #{tc[:result].to_s.slice(0, 100)}" if tc[:result]
      puts "   Error: #{tc[:error]}" if tc[:error]
    end
  end

  def show_errors
    errors.each_with_index do |err, i|
      puts "#{i + 1}. #{err[:class]}: #{err[:message]}"
      puts "   #{err[:context]}" if err[:context]
    end
  end
end

# Harness state module
module Harness
  class << self
    attr_accessor :runs, :model_id, :verbose

    def init
      @runs ||= []
      @model_id ||= ENV.fetch("MODEL_ID", "gemma-3n-e4b")
      @verbose ||= ENV.fetch("VERBOSE", "false") == "true"
    end
  end
end

Harness.init

# Enable simple logging
Smolagents::Telemetry::LoggingSubscriber.enable(level: :info)

# Main run function
def run(task, model: nil, max_steps: 10, verbose: Harness.verbose)
  model_id = model || Harness.model_id
  steps = []
  tool_calls = []
  code_blocks = []
  errors = []

  agent = Smolagents.agent
    .model { Smolagents::OpenAIModel.lm_studio(model_id) }
    .with(:code)
    .tools(:search)
    .max_steps(max_steps)
    .instructions(<<~INST)
      Search returns an array of results with 'title', 'link', 'description'.
      Access like: results[0]['title'] or results.first
      Call final_answer(answer: "...") when done.
    INST
    .on(:step_complete) do |step, ctx|
      steps << { step:, context: ctx, number: ctx.step_number }
      code_blocks << step.model_output if step.respond_to?(:model_output) && step.model_output
      puts "  Step #{ctx.step_number}" if verbose
    end
    .on(:tool_complete) do |tc, result|
      entry = { name: tc.name, args: tc.arguments, result:, error: result&.error? ? result.to_s : nil }
      tool_calls << entry
      status = entry[:error] ? "FAILED" : "ok"
      puts "    #{tc.name} -> #{status}" if verbose
    end
    .on(:error) do |cls, msg, ctx, _rec|
      errors << { class: cls, message: msg, context: ctx }
      puts "    ERROR: #{msg}" if verbose
    end
    .build

  start_time = Time.now
  result = agent.run(task)
  end_time = Time.now

  capture = RunCapture.new(
    task:, result:, steps:, tool_calls:, code_blocks:, errors:,
    start_time:, end_time:, model_id:
  )

  Harness.runs << capture
  capture.summary
  capture
end

def last_run = Harness.runs.last

def replay
  return puts("No previous run") unless last_run
  run(last_run.task, model: last_run.model_id)
end

def runs = Harness.runs

def clear_runs
  Harness.runs.clear
  puts "Cleared run history"
end

def model(model_id)
  Harness.model_id = model_id
  puts "Model set to: #{model_id}"
end

def verbose!
  Harness.verbose = true
  puts "Verbose mode enabled"
end

def quiet!
  Harness.verbose = false
  puts "Verbose mode disabled"
end

# Test Cases
TEST_CASES = {
  simple_search: "Search for Ruby tutorials",
  extract_title: "Search for Ruby tutorials and tell me the title of the first result",
  extract_link: "Search for Ruby 4.0 features and give me a link to learn more",
  multi_step: "Search for Ruby testing frameworks, then search for RSpec tutorials",
  synthesis: "Search for Ruby vs Python comparisons and summarize the key differences"
}.freeze

def test(name = :simple_search)
  task = TEST_CASES[name.to_sym] || name.to_s
  puts "Running test: #{name}"
  run(task)
end

def test_all
  TEST_CASES.each_key do |name|
    puts "\n#{"=" * 60}"
    test(name)
  end
  puts "\n#{"=" * 60}"
  puts "All tests complete. #{Harness.runs.count} runs captured."
end

def harness_help
  puts <<~HELP
    IRB Harness Commands:

    Running:
      run("task")              Run agent with task
      run("task", model: "x")  Run with specific model
      replay                   Re-run last task
      test(:simple_search)     Run a predefined test
      test_all                 Run all predefined tests

    Inspecting:
      last_run                 Get last run capture
      last_run.summary         Show summary
      last_run.show_code       Show all generated code
      last_run.show_tools      Show all tool calls
      last_run.show_errors     Show all errors
      last_run.code            Raw code blocks
      last_run.tools           Raw tool call data
      runs                     All captured runs

    Config:
      model("model-id")        Change default model
      verbose!                 Enable verbose output
      quiet!                   Disable verbose output
      clear_runs               Clear run history

    Test cases: #{TEST_CASES.keys.join(", ")}
  HELP
end

puts "IRB Harness loaded. Type 'harness_help' for commands."
puts "Model: #{Harness.model_id}"
