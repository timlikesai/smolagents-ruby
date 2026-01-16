#!/usr/bin/env ruby
# Model Compliance Test
#
# Tests model responses against the library's ACTUAL prompting.
# No custom prompts - uses Smolagents::Utilities::Prompts.
#
# Usage:
#   ruby script/model_compliance_test.rb                    # All models
#   ruby script/model_compliance_test.rb --model lfm        # Filter
#   ruby script/model_compliance_test.rb --iterations 10    # More iterations
#   ruby script/model_compliance_test.rb --append           # Append to existing results

require "bundler/setup"
require "smolagents"
require "faraday"
require "json"
require "optparse"

module ModelComplianceTest
  MODELS = %w[
    lfm2.5-1.2b-instruct
    gpt-oss-20b
    qwen/qwen3-4b
    nemotron-3-nano
    granite-4.0-h-tiny
    medgemma-1.5-4b-it
    gemma-3n-e4b
  ].freeze

  RESULTS_FILE = "script/compliance_results.json".freeze

  # Test scenarios using REAL tools from the library
  SCENARIOS = {
    search: {
      task: "What programming languages are trending in 2026?",
      tools: -> { [Smolagents::Tools::DuckDuckGoSearchTool.new, Smolagents::Tools::FinalAnswerTool.new] },
      agent_type: :code
    },
    calculation: {
      task: "What is (47 * 23) + (89 * 12)?",
      tools: -> { [Smolagents::Tools::FinalAnswerTool.new] },
      agent_type: :code
    },
    code_task: {
      task: "Write a Ruby function to check if a number is prime",
      tools: -> { [Smolagents::Tools::FinalAnswerTool.new] },
      agent_type: :code
    }
  }.freeze

  # HTTP client for model API
  class Client
    def initialize(base_url: "http://localhost:1234")
      @conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.options.timeout = 120
      end
    end

    def chat(model:, messages:)
      response = @conn.post("/v1/chat/completions") do |req|
        req.body = { model:, messages:, temperature: 0.7 }
      end
      response.body
    rescue StandardError => e
      { "error" => "#{e.class}: #{e.message}" }
    end
  end

  # Builds prompts using the LIBRARY's prompt generation
  module PromptBuilder
    def self.build(scenario)
      [{ role: "system", content: system_prompt(scenario) }, { role: "user", content: scenario[:task] }]
    end

    def self.system_prompt(scenario)
      tool_docs = scenario[:tools].call.map(&:to_tool_calling_prompt)
      prompts = Smolagents::Utilities::Prompts
      scenario[:agent_type] == :code ? prompts.code(tools: tool_docs) : prompts.agent(tools: tool_docs)
    end
  end

  # Analyzes model responses for compliance
  module ResponseAnalyzer
    def self.analyze(content)
      return { status: :error, reason: :empty_response, raw_response: nil } if content.nil? || content.empty?

      code = Smolagents::Utilities::PatternMatching.extract_code(content)
      if code
        { status: :pass, code:, has_final_answer: code.include?("final_answer"), raw_response: content }
      else
        { status: :fail, reason: detect_reason(content), raw_response: content }
      end
    end

    REASON_CHECKS = [
      [:direct_answer, ->(c) { c.match?(/\A[A-Z][^`<\[]{20,}\z/m) }],
      [:no_code_block, ->(c) { !c.include?("```") && !c.include?("<|") && !c.include?("<code") }],
      [:malformed_code, ->(c) { c.include?("```") && !c.match?(/```\w*\s/) }],
      [:has_markers_no_code, ->(c) { c.include?("<|") || c.include?("<code") }]
    ].freeze

    def self.detect_reason(content)
      REASON_CHECKS.find { |_, check| check.call(content) }&.first || :unknown_format
    end
  end

  # Manages result persistence with append support
  class ResultStore
    def initialize(append: false)
      @append = append
      @results = load_existing
    end

    def add(result) = @results << result

    def save
      File.write(RESULTS_FILE, JSON.pretty_generate(data))
    end

    def all = @results

    private

    def load_existing
      return [] unless @append && File.exist?(RESULTS_FILE)

      JSON.parse(File.read(RESULTS_FILE))["results"] || []
    rescue JSON::ParserError
      []
    end

    def data
      { timestamp: Time.now.iso8601, summary: build_summary, results: @results }
    end

    def build_summary
      {
        total: @results.size,
        passed: @results.count { |r| r[:status] == :pass || r["status"] == "pass" },
        failed: @results.count { |r| r[:status] == :fail || r["status"] == "fail" },
        by_model: results_by_model
      }
    end

    def results_by_model
      @results.group_by { |r| r[:model] || r["model"] }.transform_values do |rs|
        passed = rs.count { |r| r[:status] == :pass || r["status"] == "pass" }
        { passed:, total: rs.size, rate: "#{(passed.to_f / rs.size * 100).round(1)}%" }
      end
    end
  end

  # Test runner
  class Runner
    def initialize(options)
      @client = Client.new
      @models = filter_models(options[:model_filter])
      @iterations = options[:iterations]
      @store = ResultStore.new(append: options[:append])
    end

    def run
      puts header
      @models.each { |model| test_model(model) }
      print_summary
    end

    private

    def filter_models(filter)
      return MODELS unless filter

      MODELS.select { |m| m.downcase.include?(filter.downcase) }
    end

    def header
      <<~HEADER
        #{"=" * 70}
        Model Compliance Test - Using Library Prompts
        Models: #{@models.size} | Scenarios: #{SCENARIOS.size} | Iterations: #{@iterations}
        #{"=" * 70}

      HEADER
    end

    def test_model(model)
      puts "Testing #{model}..."
      SCENARIOS.each { |name, scenario| test_scenario(model, name, scenario) }
      puts
    end

    def test_scenario(model, name, scenario)
      @iterations.times do |i|
        result = run_test(model, name, scenario, i)
        @store.add(result)
        print result[:status] == :pass ? "." : "F"
      end
    end

    def run_test(model, scenario_name, scenario, iteration)
      messages = PromptBuilder.build(scenario)
      start = Time.now
      response = @client.chat(model:, messages:)
      elapsed = Time.now - start

      content = response.dig("choices", 0, "message", "content")
      analysis = ResponseAnalyzer.analyze(content)

      { model:, scenario: scenario_name, iteration:, elapsed: elapsed.round(2),
        prompt_tokens: response.dig("usage", "prompt_tokens"), **analysis }
    end

    def print_summary
      puts "\n#{"=" * 70}\nRESULTS\n#{"=" * 70}"
      @store.all.group_by { |r| r[:model] || r["model"] }.each { |m, rs| print_model(m, rs) }
      @store.save
      puts "\nResults saved to #{RESULTS_FILE}"
    end

    def print_model(model, results)
      passed = results.count { |r| r[:status] == :pass || r["status"] == "pass" }
      puts "#{model}: #{passed}/#{results.size} (#{(passed.to_f / results.size * 100).round(1)}%)"
      print_failures(results)
    end

    def print_failures(results)
      failures = results.select { |r| r[:status] == :fail || r["status"] == "fail" }
      return if failures.empty?

      reasons = failures.group_by { |r| r[:reason] || r["reason"] }.transform_values(&:size)
      puts "  Failures: #{reasons.inspect}"
    end
  end
end

# Parse options and run
options = { iterations: 5, model_filter: nil, append: false }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--model FILTER", "Filter models by name") { |v| options[:model_filter] = v }
  opts.on("--iterations N", Integer, "Iterations per scenario") { |v| options[:iterations] = v }
  opts.on("--append", "Append to existing results instead of overwriting") { options[:append] = true }
end.parse!

ModelComplianceTest::Runner.new(options).run
