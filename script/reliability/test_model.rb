#!/usr/bin/env ruby
# Test a single model across capability dimensions.
# Runs all tests in one session to avoid model swapping.
#
# Usage:
#   ruby script/reliability/test_model.rb MODEL_ID
#   ruby script/reliability/test_model.rb MODEL_ID --dim arithmetic,tool_usage
#   ruby script/reliability/test_model.rb --dry-run             # Test framework without model
#   ruby script/reliability/test_model.rb --dry-run --dim tool_usage
#   ruby script/reliability/test_model.rb --list

# Add lib to load path for autoloads
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "optparse"
require "smolagents"
require_relative "runner"
require_relative "logging"

DEFAULT_SERVER = "https://llama-cpp-ultra.reverse-bull.ts.net".freeze

options = {
  server: DEFAULT_SERVER,
  dimensions: nil, # nil = all dimensions
  timeout: 45,
  verbose: true,
  dry_run: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} MODEL_ID [options]"

  opts.on("--server URL", "Server URL") { |v| options[:server] = v }
  opts.on("--dim DIMS", "Dimensions to test (comma-separated)") do |v|
    options[:dimensions] = v.split(",").map { |x| x.strip.to_sym }
  end
  opts.on("--timeout N", Integer, "Timeout per test") { |v| options[:timeout] = v }
  opts.on("-q", "--quiet", "Less output") { options[:verbose] = false }
  opts.on("--list", "List loaded models") { options[:list] = true }
  opts.on("--dry-run", "Use mock model with correct answers (test framework only)") { options[:dry_run] = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit
  end
end.parse!

# Handle dry run mode vs real model mode
if options[:dry_run]
  model_id = "dry-run-mock"

  # Determine dimensions to test
  dims_to_test = options[:dimensions] || Reliability::TestDefinitions.dimension_names
  test_count = dims_to_test.sum { |d| Reliability::TestDefinitions.for_dimension(d).size }

  puts "=" * 75
  puts "DRY RUN MODE - Testing framework with mock model"
  puts "=" * 75
  puts "Dimensions: #{dims_to_test.join(", ")}"
  puts "Tests: #{test_count}"
  puts "=" * 75

  # Create logger for dry run
  logger = Reliability::Logger.new(model_id: "dry-run")
  puts "Logging to: #{logger.log_path}"
  puts "=" * 75

  logger.section("DRY RUN TEST")
  logger.info("Dimensions: #{dims_to_test.join(", ")}")
  logger.info("Tests: #{test_count}")

  runner = Reliability::Runner.new(server: nil, logger:, dry_run: true, verbose: options[:verbose])
  puts "Starting dry run tests...\n"
else
  server = Smolagents::Servers::LlamaCpp.new(api_base: options[:server])

  if options[:list]
    puts "Loaded models (ready to test):"
    server.loaded_models.each { |m| puts "  #{m.id}" }
    puts "\nCapability dimensions:"
    Reliability::TestDefinitions::DIMENSIONS.each do |key, info|
      puts "  #{key}: #{info[:name]} (#{info[:tests].size} tests)"
    end
    exit 0
  end

  model_id = ARGV[0]
  unless model_id
    puts "Usage: #{$PROGRAM_NAME} MODEL_ID [options]"
    puts "\nLoaded models:"
    server.loaded_models.each { |m| puts "  #{m.id}" }
    exit 1
  end

  # Find exact or partial match
  model = server.loaded_models.find { |m| m.id == model_id } ||
          server.loaded_models.find { |m| m.id.downcase.include?(model_id.downcase) }

  unless model
    puts "No loaded model matches '#{model_id}'"
    puts "\nLoaded models:"
    server.loaded_models.each { |m| puts "  #{m.id}" }
    exit 1
  end

  model_id = model.id

  # Determine dimensions to test
  dims_to_test = options[:dimensions] || Reliability::TestDefinitions.dimension_names
  test_count = dims_to_test.sum { |d| Reliability::TestDefinitions.for_dimension(d).size }

  puts "=" * 75
  puts "MODEL: #{model.id}"
  puts "=" * 75
  puts "Dimensions: #{dims_to_test.join(", ")}"
  puts "Tests: #{test_count}"
  puts "Timeout: #{options[:timeout]}s per test"
  puts "=" * 75

  # Create logger for this test run - captures all prompts and responses
  logger = Reliability::Logger.new(model_id: model.id)
  puts "Logging to: #{logger.log_path}"
  puts "=" * 75

  logger.section("MODEL TEST: #{model.id}")
  logger.info("Dimensions: #{dims_to_test.join(", ")}")
  logger.info("Tests: #{test_count}")
  logger.info("Timeout: #{options[:timeout]}s per test")

  runner = Reliability::Runner.new(server:, logger:)

  # Reset circuits and verify server health before starting
  runner.reset_circuits!
  unless server.healthy?
    puts "Server not healthy. Exiting."
    exit 1
  end

  # Ensure model is warmed up before testing
  unless runner.warmup_model(model.id)
    puts "Failed to warmup model. Exiting."
    exit 1
  end

  # Final circuit reset after warmup
  runner.reset_circuits!
  sleep 2 # rubocop:disable Smolagents/NoSleep -- Post-warmup stabilization

  puts "Model ready. Starting tests...\n"
end

start_time = Time.now
dimension_results = {}

dims_to_test.each do |dim|
  tests = Reliability::TestDefinitions.for_dimension(dim)
  results = tests.map { |test| runner.run_test(model_id, test, timeout: options[:timeout]) }
  dimension_results[dim] = results

  dim_info = Reliability::TestDefinitions::DIMENSIONS[dim]
  passed = results.count(&:passed)
  total = results.size

  puts "\n#{dim_info[:name]} (#{passed}/#{total})"
  puts "-" * 50

  results.each do |r|
    status = r.passed ? "✓" : "✗"
    if options[:verbose]
      puts "  #{status} #{r.name}"
      puts "    Output: #{r.output&.slice(0, 60)}..." if r.output
      puts "    Error: #{r.error}" if r.error
      puts "    Steps: #{r.steps}, Time: #{r.duration.round(1)}s"
    else
      detail = r.error || r.output&.slice(0, 40) || ""
      puts "  #{status} #{r.name}: #{detail}"
    end
  end
end

total_time = Time.now - start_time

# Summary
all_results = dimension_results.values.flatten
total_passed = all_results.count(&:passed)
total_tests = all_results.size
rate = (total_passed.to_f / total_tests * 100).round(1)

puts "\n#{"=" * 75}"
puts "RESULT: #{total_passed}/#{total_tests} (#{rate}%)"
puts "Total time: #{total_time.round(1)}s"
puts "=" * 75

# Per-dimension breakdown
puts "\nCapability Profile:"
dimension_results.each do |dim, results|
  dim_name = Reliability::TestDefinitions::DIMENSIONS[dim][:name]
  passed = results.count(&:passed)
  total = results.size
  pct = (passed.to_f / total * 100).round(0)
  bar = ("█" * (pct / 10)) + ("░" * (10 - (pct / 10)))
  puts "  #{dim_name.ljust(20)} #{bar} #{pct.to_s.rjust(3)}% (#{passed}/#{total})"
end

# Difficulty breakdown (only for tests we actually ran)
puts "\nBy Difficulty:"
# Get the tests we actually ran
tests_run = dims_to_test.flat_map { |d| Reliability::TestDefinitions.for_dimension(d) }

%i[easy medium hard].each do |diff|
  tests_at_diff = tests_run.select { |t| t[:difficulty] == diff }
  test_names = tests_at_diff.map { |t| t[:name] }
  passed_at_diff = all_results.select { |r| test_names.include?(r.name) && r.passed }
  total = tests_at_diff.size
  passed = passed_at_diff.size
  pct = total.positive? ? (passed.to_f / total * 100).round(0) : 0
  bar = ("█" * (pct / 10)) + ("░" * (10 - (pct / 10)))
  puts "  #{diff.to_s.capitalize.ljust(10)} #{bar} #{pct.to_s.rjust(3)}% (#{passed}/#{total})"
end

# Log final summary and close
logger.section("FINAL SUMMARY")
logger.info("Result: #{total_passed}/#{total_tests} (#{rate}%)")
dimension_results.each do |dim, results|
  dim_name = Reliability::TestDefinitions::DIMENSIONS[dim][:name]
  passed = results.count(&:passed)
  total = results.size
  logger.info("  #{dim_name}: #{passed}/#{total}")
end
logger.close
