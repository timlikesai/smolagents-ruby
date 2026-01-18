#!/usr/bin/env ruby
# rubocop:disable all

# Interactive agent testing script with verbose logging
#
# Run with code agent (writes Ruby): bundle exec ruby test_agent.rb [question]
# Run with tool agent (JSON calls): AGENT_TYPE=tool bundle exec ruby test_agent.rb [question]
#
# Environment variables:
#   AGENT_TYPE  - "code" (default) or "tool"
#   MODEL_ID    - Model name (default: gemma-3n-e4b)
#   MAX_STEPS   - Maximum steps (default: 6)
#   SEARXNG_URL - SearXNG instance URL
#   VERBOSE     - Set to show full model output (default: truncated)

require "bundler/setup"
require "smolagents"

# Configuration
SEARXNG_URL = ENV.fetch("SEARXNG_URL", "https://searxng.reverse-bull.ts.net")
MODEL_ID = ENV.fetch("MODEL_ID", "gemma-3n-e4b")
MAX_STEPS = ENV.fetch("MAX_STEPS", 6).to_i
AGENT_TYPE = ENV.fetch("AGENT_TYPE", "code").to_sym
VERBOSE = ENV.key?("VERBOSE")

def separator(title = nil)
  puts "\n#{"=" * 70}"
  puts "  #{title}" if title
  puts "=" * 70
end

def truncate(text, max = 500)
  return text if VERBOSE || text.to_s.length <= max
  "#{text.to_s.slice(0, max)}... (truncated, set VERBOSE=1 for full output)"
end

def build_agent
  searxng = Smolagents::SearxngSearchTool.new(instance_url: SEARXNG_URL)

  Smolagents.agent(AGENT_TYPE)
    .model { Smolagents::OpenAIModel.lm_studio(MODEL_ID) }
    .tools(searxng)
    .max_steps(MAX_STEPS)
    .on(:before_step) do |step_number:|
      separator "STEP #{step_number}"
    end
    .on(:after_step) do |step:, monitor:|
      # Show what the model said
      if step.model_output_message
        msg = step.model_output_message
        puts "Model output:"
        puts truncate(msg.content) if msg.content&.length&.positive?
        if msg.tool_calls&.any?
          msg.tool_calls.each do |tc|
            puts "  Tool call: #{tc.name}(#{tc.arguments.inspect})"
          end
        end
      end

      # Show tool results
      if step.tool_calls&.any?
        puts "\nTool results:"
        step.tool_calls.each do |tc|
          puts "  #{tc.name}: (executed)"
        end
      end

      # Show observations (what went back to the model)
      if step.observations&.length&.positive?
        puts "\nObservations:"
        puts truncate(step.observations, 300)
      end

      # Show any errors
      puts "\nError: #{step.error}" if step.error

      # Show timing and tokens
      puts "\nDuration: #{monitor.duration.round(2)}s"
      if step.token_usage
        puts "Tokens: #{step.token_usage.input_tokens} in, #{step.token_usage.output_tokens} out"
      end
    end
    .on(:tool_call_requested) do |tool_name:, args:|
      puts "  → Calling #{tool_name}(#{args.inspect})"
    end
    .on(:tool_call_completed) do |tool_name:, is_final:|
      status = is_final ? " [FINAL ANSWER]" : ""
      puts "  ← #{tool_name} completed#{status}"
    end
    .build
end

def run_test(question)
  separator "BUILDING AGENT"
  puts "Type: #{AGENT_TYPE}"
  puts "Model: #{MODEL_ID}"
  puts "SearXNG: #{SEARXNG_URL}"
  puts "Max steps: #{MAX_STEPS}"

  agent = build_agent

  separator "RUNNING TASK"
  puts "Question: #{question}"

  start_time = Time.now
  result = agent.run(question)
  elapsed = Time.now - start_time

  separator "FINAL RESULT"
  puts "Answer: #{result.output}"
  puts "State: #{result.state}"
  puts "Steps: #{result.steps.size}"
  puts "Time: #{elapsed.round(2)}s"

  if result.token_usage
    puts "Total tokens: #{result.token_usage.total_tokens}"
  end
end

# Main
question = ARGV.join(" ").strip
question = "What is the capital of Japan?" if question.empty?

run_test(question)
