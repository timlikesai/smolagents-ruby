#!/usr/bin/env ruby
# rubocop:disable all

# Interactive agent testing script with verbose logging
# Run: bundle exec ruby test_agent.rb [question]

require "bundler/setup"
require "smolagents"

# Configuration
SEARXNG_URL = ENV.fetch("SEARXNG_URL", "https://searxng.reverse-bull.ts.net")
MODEL_ID = ENV.fetch("MODEL_ID", "gemma-3n-e4b")
MAX_STEPS = ENV.fetch("MAX_STEPS", 6).to_i

def separator(title = nil)
  puts "\n#{"=" * 70}"
  puts "  #{title}" if title
  puts "=" * 70
end

def build_agent
  searxng = Smolagents::SearxngSearchTool.new(instance_url: SEARXNG_URL)

  agent = Smolagents.agent(:code)
    .model { Smolagents::OpenAIModel.lm_studio(MODEL_ID) }
    .tools(searxng)
    .max_steps(MAX_STEPS)
    .build

  # Hook to log model inputs/outputs
  original_generate = agent.instance_variable_get(:@model).method(:generate)
  step_count = 0

  agent.instance_variable_get(:@model).define_singleton_method(:generate) do |messages, **opts|
    step_count += 1
    separator "STEP #{step_count} - INPUT TO MODEL"

    # Show system prompt only on first step
    if step_count == 1
      system_msg = messages.find { |m| m.respond_to?(:role) && m.role == "system" }
      if system_msg
        puts "System prompt:"
        puts system_msg.content.to_s.lines.first(30).join
        puts "... (truncated)" if system_msg.content.to_s.lines.size > 30
      end
    end

    # Show the last user/observation message
    last_msg = messages.last
    if last_msg.respond_to?(:role)
      puts "\nLast message (#{last_msg.role}):"
      puts last_msg.content.to_s.slice(0, 500)
      puts "... (truncated)" if last_msg.content.to_s.length > 500
    end

    result = original_generate.call(messages, **opts)

    separator "STEP #{step_count} - MODEL OUTPUT"
    puts result.content.to_s
    puts

    result
  end

  agent
end

def run_test(question)
  separator "BUILDING AGENT"
  puts "Model: #{MODEL_ID}"
  puts "SearXNG: #{SEARXNG_URL}"
  puts "Max steps: #{MAX_STEPS}"

  agent = build_agent

  separator "SYSTEM PROMPT (full)"
  puts agent.instance_variable_get(:@memory).instance_variable_get(:@system_prompt).system_prompt

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
end

# Main
question = ARGV.join(" ").strip
question = "What is the capital of Japan?" if question.empty?

run_test(question)
