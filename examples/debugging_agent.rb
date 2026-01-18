#!/usr/bin/env ruby
# rubocop:disable all

# Debugging Agent Example
#
# A fully-instrumented agent that exposes internal state for debugging.
# Shows how to:
# - Use the full DSL with all options
# - Hook into every event for visibility
# - Capture and inspect generated code
# - Track tool calls and results
# - Monitor memory and context
# - Control execution flow
#
# Usage:
#   ruby examples/debugging_agent.rb "your task"
#   ruby examples/debugging_agent.rb  # uses default task
#
# Environment:
#   MODEL_ID      - Model to use (default: gemma-3n-e4b)
#   LM_STUDIO_URL - LM Studio URL (default: http://localhost:1234)
#   DEBUG_LEVEL   - Verbosity: minimal, normal, verbose (default: normal)

require "smolagents"
require "json"
require "fileutils"

# =============================================================================
# Model Capture Wrapper - Logs all model I/O to JSONL files
# =============================================================================

class ModelCapture
  attr_reader :call_count, :output_dir

  def initialize(model, output_dir: "tmp/model_captures")
    @model = model
    @output_dir = output_dir
    @call_count = 0
    FileUtils.mkdir_p(@output_dir)
    puts "Model captures will be saved to: #{@output_dir}"
  end

  def generate(messages, **kwargs)
    @call_count += 1
    call_id = format("%03d", @call_count)

    # Capture input
    input_data = {
      call_id: call_id,
      timestamp: Time.now.iso8601,
      type: "input",
      messages: messages.map { |m| serialize_message(m) },
      kwargs: kwargs
    }
    write_jsonl("#{call_id}_input.jsonl", input_data)

    # Call the real model
    response = @model.generate(messages, **kwargs)

    # Capture output
    output_data = {
      call_id: call_id,
      timestamp: Time.now.iso8601,
      type: "output",
      content: response.content,
      tool_calls: response.tool_calls&.map { |tc| serialize_tool_call(tc) },
      token_usage: serialize_token_usage(response.token_usage)
    }
    write_jsonl("#{call_id}_output.jsonl", output_data)

    response
  end

  # Delegate other methods to the wrapped model
  def method_missing(method, *args, **kwargs, &block)
    @model.send(method, *args, **kwargs, &block)
  end

  def respond_to_missing?(method, include_private = false)
    @model.respond_to?(method, include_private)
  end

  private

  def serialize_message(msg)
    {
      role: msg.role.to_s,
      content: msg.content,
      tool_calls: msg.tool_calls&.map { |tc| serialize_tool_call(tc) }
    }.compact
  end

  def serialize_tool_call(tc)
    return nil unless tc
    { id: tc.id, name: tc.name, arguments: tc.arguments } rescue tc.to_h rescue tc.to_s
  end

  def serialize_token_usage(tu)
    return nil unless tu
    { input: tu.input_tokens, output: tu.output_tokens, total: tu.total_tokens } rescue tu.to_h rescue nil
  end

  def write_jsonl(filename, data)
    File.open(File.join(@output_dir, filename), "w") do |f|
      f.puts JSON.pretty_generate(data)
    end
  end
end

# =============================================================================
# Debug Logger - Captures everything for analysis
# =============================================================================

class DebugLogger
  attr_reader :steps, :tool_calls, :generated_code, :errors, :model_calls

  def initialize(level: :normal)
    @level = level
    @steps = []
    @tool_calls = []
    @generated_code = []
    @errors = []
    @model_calls = []
    @start_time = nil
  end

  def start!
    @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    log(:header, "Agent Starting")
  end

  def elapsed = @start_time ? (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time).round(2) : 0

  def log(type, message, details = {})
    timestamp = "[#{elapsed}s]"
    case type
    when :header
      puts "\n#{"=" * 70}"
      puts "#{timestamp} #{message}"
      puts "=" * 70
    when :step
      puts "\n#{timestamp} Step #{details[:number]} #{"-" * 50}"
    when :code
      @generated_code << details[:code]
      if verbose?
        puts "#{timestamp} Generated Code:"
        puts details[:code].lines.map { |l| "    #{l}" }.join
      end
    when :tool
      @tool_calls << details
      status = details[:success] ? "OK" : "FAILED"
      puts "#{timestamp}   #{details[:name]} -> #{status}"
      puts "#{timestamp}     Args: #{details[:args].inspect}" if verbose? && details[:args]
      if details[:result] && (verbose? || !details[:success])
        preview = details[:result].to_s[0, 200]
        preview += "..." if details[:result].to_s.length > 200
        puts "#{timestamp}     Result: #{preview}"
      end
    when :error
      @errors << details
      puts "#{timestamp}   ERROR: #{details[:message]}"
      puts "#{timestamp}     Context: #{details[:context]}" if details[:context]
    when :model
      @model_calls << details
      puts "#{timestamp}   Model: #{details[:tokens]} tokens" if verbose?
    when :observation
      if verbose?
        preview = message.to_s[0, 300]
        preview += "..." if message.to_s.length > 300
        puts "#{timestamp}   Observation: #{preview}"
      end
    when :evaluation
      emoji = { goal_achieved: "DONE", continue: "...", stuck: "STUCK" }[details[:status]] || "?"
      puts "#{timestamp}   Eval: #{emoji} (confidence: #{details[:confidence]})"
      puts "#{timestamp}     Reason: #{details[:reasoning]}" if verbose? && details[:reasoning]
    when :final
      puts "\n#{timestamp} Final Answer:"
      puts message.to_s.lines.map { |l| "    #{l}" }.join
    when :info
      puts "#{timestamp} #{message}"
    end
  end

  def record_step(step, context)
    @steps << { step:, context:, timestamp: elapsed }
    log(:step, nil, number: context.step_number)
    log(:code, nil, code: step.model_output) if step.respond_to?(:model_output) && step.model_output
  end

  def verbose? = @level == :verbose
  def minimal? = @level == :minimal

  def summary
    puts "\n#{"=" * 70}"
    puts "DEBUG SUMMARY"
    puts "=" * 70
    puts "Steps: #{@steps.count}"
    puts "Tool calls: #{@tool_calls.count} (#{@tool_calls.count(&:success)} succeeded)"
    puts "Errors: #{@errors.count}"
    puts "Model calls: #{@model_calls.count}"
    puts "Total time: #{elapsed}s"

    if @errors.any?
      puts "\nErrors encountered:"
      @errors.each_with_index do |err, i|
        puts "  #{i + 1}. #{err[:message]}"
      end
    end

    if @tool_calls.any?
      puts "\nTool call sequence:"
      @tool_calls.each_with_index do |tc, i|
        status = tc[:success] ? "OK" : "FAIL"
        puts "  #{i + 1}. #{tc[:name]} [#{status}]"
      end
    end
  end
end

# =============================================================================
# Configuration
# =============================================================================

MODEL_ID = ENV.fetch("MODEL_ID", "gemma-3n-e4b")
LM_STUDIO_URL = ENV.fetch("LM_STUDIO_URL", "http://localhost:1234")
DEBUG_LEVEL = ENV.fetch("DEBUG_LEVEL", "normal").to_sym
MAX_STEPS = 10

# =============================================================================
# Build the Debugging Agent
# =============================================================================

debug = DebugLogger.new(level: DEBUG_LEVEL)

# Enable telemetry logging for additional visibility
Smolagents::Telemetry::LoggingSubscriber.enable(level: :info)

# Wrap model for capture
raw_model = Smolagents::OpenAIModel.lm_studio(MODEL_ID)
captured_model = ModelCapture.new(raw_model)

agent = Smolagents.agent
  .model { captured_model }
  .with(:code)
  .tools(:search)
  .max_steps(MAX_STEPS)
  .instructions(<<~INSTRUCTIONS)
    You are a helpful assistant. When searching:
    1. Use searxng_search to find information
    2. The search returns an array of results with 'title', 'link', 'description'
    3. Access results like: results[0]['title'] or results.first['link']
    4. Always examine the search results before providing an answer
    5. Call final_answer(answer: "your answer") when done
  INSTRUCTIONS
  .on(:step_complete) { |step, ctx| debug.record_step(step, ctx) }
  .on(:task_complete) do |outcome, output, steps_taken|
    debug.log(:info, "Task complete: #{outcome} after #{steps_taken} steps")
    debug.log(:final, output) if output
  end
  .on(:tool_complete) do |tool_call, result|
    debug.log(:tool, nil, name: tool_call.name, args: tool_call.arguments,
                          result:, success: !result&.error?)
  end
  .on(:error) do |error_class, error_message, context, recoverable|
    debug.log(:error, nil, class: error_class, message: error_message,
                           context:, recoverable:)
  end
  .on(:evaluation_complete) do |step_number, status, answer, reasoning, confidence|
    debug.log(:evaluation, nil, step: step_number, status:, answer:, reasoning:, confidence:)
  end
  .on(:repetition_detected) { |pat, cnt, guide| debug.log(:info, "Repetition: #{pat} (#{cnt}x) - #{guide}") }
  .on(:goal_drift) { |lvl, rel, _| debug.log(:info, "Goal drift: #{lvl} (relevance: #{rel})") }
  .build

# =============================================================================
# Run the Agent
# =============================================================================

task = ARGV[0] || "Search for beginner-friendly Ruby tutorials and tell me the best one"

puts "=" * 70
puts "DEBUGGING AGENT"
puts "=" * 70
puts "Task: #{task}"
puts "Model: #{MODEL_ID}"
puts "Debug level: #{DEBUG_LEVEL}"
puts "Max steps: #{MAX_STEPS}"
puts "-" * 70

debug.start!

begin
  result = agent.run(task)
  debug.summary

  puts "\n#{"=" * 70}"
  puts "RESULT"
  puts "=" * 70
  puts "Status: #{result.state}"
  puts "Output: #{result.output}"
  puts "Tokens: #{result.token_usage.total_tokens} total" if result.token_usage
  puts "\nModel captures: #{captured_model.output_dir}/ (#{captured_model.call_count} calls)"
rescue Smolagents::AgentMaxStepsError => e
  debug.log(:error, nil, message: "Max steps reached", context: e.message)
  debug.summary
  puts "\nAgent hit step limit. Check debug summary for analysis."
  puts "Model captures: #{captured_model.output_dir}/ (#{captured_model.call_count} calls)"
rescue Smolagents::AgentError => e
  debug.log(:error, nil, message: e.message, context: e.class.name)
  debug.summary
  puts "\nAgent error: #{e.message}"
  puts "Model captures: #{captured_model.output_dir}/ (#{captured_model.call_count} calls)"
rescue StandardError => e
  debug.log(:error, nil, message: e.message, context: e.backtrace.first(3).join("\n"))
  debug.summary
  puts "\nUnexpected error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  puts "Model captures: #{captured_model.output_dir}/ (#{captured_model.call_count} calls)"
end

# =============================================================================
# Interactive Debug Mode (when run in IRB)
# =============================================================================
#
# After running, you can inspect:
#   debug.steps          - All step data
#   debug.tool_calls     - All tool calls with args/results
#   debug.generated_code - All code the model generated
#   debug.errors         - All errors encountered
#   agent                - The agent instance for further runs
#
# Example IRB session:
#   require_relative 'examples/debugging_agent'
#   debug.generated_code.each { |code| puts code; puts "---" }
#   debug.tool_calls.select { |tc| !tc[:success] }
