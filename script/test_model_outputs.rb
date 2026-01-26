#!/usr/bin/env ruby
# Test raw model outputs for code block parsing analysis.
#
# Usage:
#   ruby script/test_model_outputs.rb              # Test all models
#   ruby script/test_model_outputs.rb gpt-oss-20b  # Test single model

require "bundler/setup"
require "smolagents"
require "json"

# Tests model outputs and code extraction.
class ModelOutputTest
  ALL_MODELS = %w[
    lfm2.5-1.2b-instruct gpt-oss-20b qwen/qwen3-4b nemotron-3-nano
    granite-4.0-h-tiny medgemma-1.5-4b-it gemma-3n-e4b
  ].freeze

  TASK = "What programming languages are trending in 2026?".freeze
  OUTPUT_FILE = File.join(__dir__, "model_test_results.json")

  def initialize(filter = nil)
    @models = filter ? ALL_MODELS.select { |m| m.include?(filter) } : ALL_MODELS
    validate_models!
    @results = []
  end

  def run
    print_system_prompt
    @models.each { |model| test_model(model) }
    print_summary
    save_results
  end

  private

  def validate_models! = @models.empty? && abort("No models match. Available: #{ALL_MODELS.join(", ")}")

  def print_system_prompt
    puts "=" * 80, "SYSTEM PROMPT:", "=" * 80, system_prompt, ""
  end

  def test_model(model_id)
    puts "=" * 80, "Testing: #{model_id}", "=" * 80
    response = call_model(model_id)
    process_response(model_id, response)
  end

  def process_response(model_id, response)
    return record_error(model_id, response["error"]) if response["error"]

    content = response.dig("choices", 0, "message", "content") || ""
    print_content(content)
    record_success(model_id, content)
  end

  def record_error(model_id, error)
    puts "ERROR: #{error}"
    @results << { model: model_id, error: }
  end

  def print_content(content)
    puts "\nRAW CONTENT (first 2000 chars):", "-" * 40
    puts content[0, 2000]
    puts "-" * 40, "\nEXTRACTED CODE:", "-" * 40
    puts extract_code(content) || "(nil - no code block found)"
    puts "-" * 40, ""
  end

  def record_success(model_id, content)
    extracted = extract_code(content)
    @results << { model: model_id, content_length: content.length,
                  extracted: !extracted.nil?, raw_content: content }
  end

  def print_summary
    puts "=" * 80, "SUMMARY", "=" * 80
    @results.each { |r| puts "#{r[:extracted] ? "✓" : "✗"} #{r[:model]}" unless r[:error] }
  end

  def save_results
    File.write(OUTPUT_FILE, JSON.pretty_generate(@results))
    puts "\nResults saved to: #{OUTPUT_FILE}"
  end

  def call_model(model_id)
    conn.post("/v1/chat/completions") { |r| r.body = { model: model_id, messages:, temperature: 0.7 } }.body
  rescue StandardError => e
    { "error" => e.message }
  end

  def conn
    @conn ||= Faraday.new(url: "http://localhost:1234") do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end
  end

  def messages
    @messages ||= [{ role: "system", content: system_prompt }, { role: "user", content: "Task: #{TASK}" }]
  end

  def system_prompt
    @system_prompt ||= Smolagents::Utilities::Prompts::CodeAgent.generate(tools: tool_docs, custom: nil)
  end

  def tool_docs
    ["searxng_search(query: term) - Search web", "final_answer(answer: result) - Return answer"]
  end

  def extract_code(content) = Smolagents::Utilities::PatternMatching.extract_code(content)
end

ModelOutputTest.new(ARGV.first&.downcase).run
