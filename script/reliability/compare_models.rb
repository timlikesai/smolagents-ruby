#!/usr/bin/env ruby
# Model reliability comparison - runs ALL tests on one model before moving to next.
# This minimizes model swapping overhead on the llama.cpp server.
#
# Usage:
#   ruby script/reliability/compare_models.rb                    # All loaded models
#   ruby script/reliability/compare_models.rb --level 1-3        # Specific levels
#   ruby script/reliability/compare_models.rb --model LFM        # Specific model
#   ruby script/reliability/compare_models.rb --timeout 30       # Custom timeout

# Add lib to load path for autoloads
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "optparse"
require "smolagents"
require_relative "runner"
require_relative "logging"

DEFAULT_SERVER = "https://llama-cpp-ultra.reverse-bull.ts.net".freeze

options = {
  server: DEFAULT_SERVER,
  levels: 1..7,
  model: nil,
  timeout: 45,
  verbose: false,
  loaded_only: true
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("--server URL", "Server URL") { |v| options[:server] = v }
  opts.on("--level RANGE", "Level range (e.g., 1-3 or 2)") do |v|
    if v.include?("-")
      parts = v.split("-").map(&:to_i)
      options[:levels] = parts[0]..parts[1]
    else
      options[:levels] = v.to_i..v.to_i
    end
  end
  opts.on("--model PATTERN", "Model name pattern (only test matching)") { |v| options[:model] = v }
  opts.on("--timeout N", Integer, "Timeout per test in seconds") { |v| options[:timeout] = v }
  opts.on("-v", "--verbose", "Show detailed output per test") { options[:verbose] = true }
  opts.on("--include-unloaded", "Also test unloaded models (will warmup)") { options[:loaded_only] = false }
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Connect to server
server = Smolagents::Servers::LlamaCpp.new(api_base: options[:server])

# Find models to test - prefer loaded models to avoid warmup delays
available = options[:loaded_only] ? server.loaded_models : server.models.reject(&:failed?)

models = if options[:model]
           available.select { |m| m.id.downcase.include?(options[:model].downcase) }
         else
           available
         end

if models.empty?
  puts "No models found matching criteria."
  puts "\nLoaded models:"
  server.loaded_models.each { |m| puts "  #{m.id}" }
  puts "\nAll models (use --include-unloaded):"
  server.models.reject(&:failed?).each { |m| puts "  #{m.id} (#{m.status})" }
  exit 1
end

levels_desc = if options[:levels].size == 1
                options[:levels].first.to_s
              else
                "#{options[:levels].first}-#{options[:levels].last}"
              end

puts "=" * 70
puts "MODEL RELIABILITY COMPARISON"
puts "=" * 70
puts "Server: #{options[:server]}"
puts "Models: #{models.size} (#{models.map(&:id).join(", ")})"
puts "Levels: #{levels_desc} (#{options[:levels].sum do |l|
  Reliability::TestDefinitions.for_level(l).size
end} tests per model)"
puts "Timeout: #{options[:timeout]}s per test"
puts "Strategy: Run ALL tests on each model before switching (minimizes warmup)"
puts "=" * 70

all_results = {}
loggers = []

models.each_with_index do |model_info, idx|
  puts "\n>>> [#{idx + 1}/#{models.size}] Testing: #{model_info.id}"
  puts "    Status: #{model_info.status}"

  # Create a new logger and runner for each model to capture all prompts/responses
  logger = Reliability::Logger.new(model_id: model_info.id)
  loggers << logger
  puts "    Logging to: #{logger.log_path}"

  logger.section("MODEL COMPARISON: #{model_info.id}")
  logger.info("Levels: #{options[:levels]}")

  runner = Reliability::Runner.new(server:, logger:)

  # Reset circuits before each model
  runner.reset_circuits!

  # Run ALL levels for this model before moving to next
  results = runner.run_levels(model_info.id, levels: options[:levels], timeout: options[:timeout])

  # Print results
  results.each do |level, level_results|
    level_name = Reliability::TestDefinitions::ALL_LEVELS[level][:name]
    passed = level_results.count(&:passed)
    total = level_results.size

    puts "    Level #{level} (#{level_name}): #{passed}/#{total}"

    next unless options[:verbose]

    level_results.each do |r|
      status = r.passed ? "✓" : "✗"
      detail = r.error || r.output&.slice(0, 40)
      puts "      #{status} #{r.name}: #{detail} (#{r.steps} steps, #{r.duration.round(1)}s)"
    end
  end

  summary = runner.summarize(results)
  all_results[model_info.id] = summary
  puts "    TOTAL: #{summary[:passed]}/#{summary[:total]} (#{summary[:rate]}%)"
end

# Final summary table
puts "\n#{"=" * 70}"
puts "SUMMARY"
puts "=" * 70
puts "Model                                           Pass  Total    Rate"
puts "-" * 70

all_results.sort_by { |_, s| -s[:rate] }.each do |model_id, summary|
  puts format("%-45<model>s %6<passed>d %6<total>d %6.1<rate>f%%",
              model: model_id[0..44],
              passed: summary[:passed],
              total: summary[:total],
              rate: summary[:rate])
end

# Close all loggers
loggers.each(&:close)
puts "\nLog files saved to: logs/reliability/"
