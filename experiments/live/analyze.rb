#!/usr/bin/env ruby
# Analyze experiment results from traces.jsonl
#
# Usage:
#   ruby experiments/live/analyze.rb <log_dir>
#   ruby experiments/live/analyze.rb experiments/live/data/logs/2026-01-26/code_generation_20260126_085828_cbca144b

require "json"

def analyze(log_dir)
  traces_file = File.join(log_dir, "traces.jsonl")
  events_file = File.join(log_dir, "events.jsonl")
  summary_file = File.join(log_dir, "summary.json")

  unless File.exist?(traces_file)
    puts "Error: traces.jsonl not found in #{log_dir}"
    exit 1
  end

  # Load summary
  summary = JSON.parse(File.read(summary_file))
  puts "=" * 60
  puts "Run: #{summary["run_id"]}"
  puts "Stats: #{summary["stats"]}"
  puts "=" * 60

  # Analyze traces
  traces = File.readlines(traces_file).map { |line| JSON.parse(line) }
  puts "\nTotal traces: #{traces.size}"

  # Group by task
  by_task = traces.group_by { |t| t["task_id"] }
  puts "Unique tasks: #{by_task.size}"

  # Analyze errors
  errors = traces.select { |t| t.dig("llm_response", "success") == false }
  puts "\nError traces: #{errors.size}"

  error_types = errors.group_by { |e| e.dig("llm_response", "error_class") }
  puts "\nError types:"
  error_types.each do |type, errs|
    puts "  #{type}: #{errs.size}"
    # Show first error message
    puts "    Example: #{errs.first.dig("llm_response", "error_message")[0..100]}"
  end

  # Token usage
  successful = traces.select { |t| t.dig("llm_response", "success") == true }
  total_input = successful.sum { |t| t.dig("llm_response", "token_usage", "input_tokens") || 0 }
  total_output = successful.sum { |t| t.dig("llm_response", "token_usage", "output_tokens") || 0 }
  puts "\nToken usage (successful calls):"
  puts "  Input tokens: #{total_input}"
  puts "  Output tokens: #{total_output}"
  puts "  Total: #{total_input + total_output}"

  # Latency analysis
  durations = successful.map { |t| t.dig("llm_response", "duration_ms") }.compact
  if durations.any?
    puts "\nLatency (successful calls):"
    puts "  Min: #{durations.min}ms"
    puts "  Max: #{durations.max}ms"
    puts "  Avg: #{(durations.sum / durations.size.to_f).round(1)}ms"
    puts "  Median: #{durations.sort[durations.size / 2]}ms"
  end

  # Load events for task results
  events = File.readlines(events_file).map { |line| JSON.parse(line) }
  task_results = events.select { |e| e["type"] == "task_complete" }

  puts "\nTask results:"
  by_model = task_results.group_by { |r| r["model"] }
  by_model.each do |model, results|
    passed = results.count { |r| r["passed"] }
    total = results.size
    avg_duration = (results.sum { |r| r["duration_ms"] } / results.size.to_f).round(1)
    puts "  #{model}: #{passed}/#{total} passed (#{(passed * 100.0 / total).round(1)}%), avg #{avg_duration}ms"
  end

  # Show sample failures
  puts "\nSample failures (first 3):"
  failures = task_results.select { |r| !r["passed"] }.first(3)
  failures.each do |f|
    prompt = (f["prompt"] || f["result"] || "unknown")[0..60]
    puts "  - #{f["model"]}: #{prompt}..."
    puts "    State: #{f["state"]}, Steps: #{f["steps"]}"
  end
end

if ARGV.empty?
  # Find most recent log directory
  logs_base = File.join(__dir__, "data", "logs")
  if Dir.exist?(logs_base)
    latest_date = Dir.entries(logs_base).reject { |d| d.start_with?(".") }.sort.last
    if latest_date
      latest_run = Dir.entries(File.join(logs_base, latest_date))
                      .reject { |d| d.start_with?(".") }
                      .sort.last
      if latest_run
        analyze(File.join(logs_base, latest_date, latest_run))
        exit 0
      end
    end
  end
  puts "Usage: ruby analyze.rb <log_dir>"
  puts "       ruby analyze.rb  # analyze most recent run"
else
  analyze(ARGV[0])
end
