#!/usr/bin/env ruby
# Stress test for model output parsing across multiple prompts and scenarios.
#
# Usage:
#   ruby script/model_stress_test.rb                    # Run all tests
#   ruby script/model_stress_test.rb --model gpt-oss    # Filter by model
#   ruby script/model_stress_test.rb --resume           # Resume from last run

require "bundler/setup"
require "smolagents"
require "json"
require "optparse"

# HTTP client for model API calls.
module ModelClient
  def conn
    @conn ||= Faraday.new(url: "http://localhost:1234") do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end
  end

  def call_model(model_id, messages)
    conn.post("/v1/chat/completions") { |r| r.body = { model: model_id, messages:, temperature: 0.7 } }.body
  rescue StandardError => e
    { "error" => "#{e.class}: #{e.message}" }
  end
end

# Summary tracking and reporting.
module SummaryReporter
  RESULTS_FILE = File.join(__dir__, "stress_test_results.jsonl")
  SUMMARY_FILE = File.join(__dir__, "stress_test_summary.json")

  def new_summary = { total: 0, passed: 0, failed: 0, errors: 0, by_model: {}, by_scenario: {} }

  def update_summary(status, model, scenario)
    @summary[:total] += 1
    @summary[status] += 1
    @summary[:by_model][model][status] += 1
    @summary[:by_scenario][scenario][status] += 1
  end

  def save_result(result) = File.open(RESULTS_FILE, "a") { |f| f.puts(JSON.generate(result)) }

  def save_and_print_summary
    File.write(SUMMARY_FILE, JSON.pretty_generate(@summary))
    puts "\n#{"=" * 70}\nSUMMARY\n#{"=" * 70}"
    puts "Total: #{@summary[:total]} | Passed: #{@summary[:passed]} | Failed: #{@summary[:failed]}"
    @summary[:by_model].each { |m, s| puts "  #{m}: #{s[:passed]}/#{s.values.sum} (#{rate(s)}%)" }
  end

  def rate(stats) = stats.values.sum.positive? ? (stats[:passed].to_f / stats.values.sum * 100).round(1) : 0
end

# Stress test runner for model output parsing.
class ModelStressTest
  include ModelClient
  include SummaryReporter

  ALL_MODELS = %w[lfm2.5-1.2b-instruct gpt-oss-20b qwen/qwen3-4b nemotron-3-nano].freeze
  TEST_SCENARIOS = [
    { name: "search", task: "Capital of France?", tools: ["search(query:)", "final_answer(answer:)"] },
    { name: "calc", task: "25 times 17?", tools: ["calculate(expression:)", "final_answer(answer:)"] },
    { name: "code", task: "Prime number function", tools: ["final_answer(answer:)"] }
  ].freeze

  def initialize(options)
    @options = options
    @models = options[:model_filter] ? ALL_MODELS.select { |m| m.include?(options[:model_filter]) } : ALL_MODELS
    @completed = options[:resume] ? load_completed : Set.new
    @summary = new_summary
    @current = 0
  end

  def run
    abort("No models match. Available: #{ALL_MODELS.join(", ")}") if @models.empty?
    File.truncate(RESULTS_FILE, 0) if File.exist?(RESULTS_FILE) && !@options[:resume]
    puts "=" * 70, "Model Stress Test - #{@models.size} models × #{TEST_SCENARIOS.size} scenarios", "=" * 70, ""
    @models.each { |model| run_model(model) }
    save_and_print_summary
  end

  private

  def run_model(model)
    @summary[:by_model][model] ||= { passed: 0, failed: 0, errors: 0 }
    TEST_SCENARIOS.each { |s| run_scenario(model, s) }
  end

  def run_scenario(model, scenario)
    @summary[:by_scenario][scenario[:name]] ||= { passed: 0, failed: 0, errors: 0 }
    @options[:iterations].times { |i| run_test(model, scenario, i) }
  end

  def run_test(model, scenario, iteration)
    @current += 1
    key = "#{model}|#{scenario[:name]}|#{iteration}"
    return puts("[#{@current}] SKIP #{key}") if @completed.include?(key)

    print "[#{@current}] #{model}/#{scenario[:name]}... "
    result = execute(model, scenario, iteration)
    record(result, model, scenario[:name])
  end

  def execute(model, scenario, iteration)
    start = Time.now
    response = call_model(model, messages(scenario))
    content = response.dig("choices", 0, "message", "content") || ""
    { model:, scenario: scenario[:name], iteration:, content:, error: response["error"],
      extracted: Smolagents::Utilities::PatternMatching.extract_code(content), elapsed: (Time.now - start).round(2) }
  end

  def messages(scenario)
    [{ role: "system", content: "Ruby code agent. Tools: #{scenario[:tools].join(", ")}" },
     { role: "user", content: scenario[:task] }]
  end

  def record(result, model, scenario)
    status = determine_status(result)
    update_summary(status, model, scenario)
    save_result(result.merge(status:))
    puts status_symbol(status)
  end

  def determine_status(result)
    return :error if result[:error]
    return :passed if result[:extracted]

    :failed
  end

  def status_symbol(status)
    { passed: "✓", error: "ERROR", failed: "✗" }[status]
  end

  def load_completed
    return Set.new unless File.exist?(RESULTS_FILE)

    Set.new(File.foreach(RESULTS_FILE).map { |l| JSON.parse(l).values_at("model", "scenario", "iteration").join("|") })
  end
end

options = { iterations: 3, resume: false, model_filter: nil }
OptionParser.new do |opts|
  opts.on("--model FILTER", "Filter models") { |v| options[:model_filter] = v.downcase }
  opts.on("--iterations N", Integer, "Iterations") { |v| options[:iterations] = v }
  opts.on("--resume", "Resume from last run") { options[:resume] = true }
end.parse!

ModelStressTest.new(options).run
