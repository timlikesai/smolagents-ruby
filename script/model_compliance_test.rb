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
  class PromptBuilder
    def self.build(scenario)
      system_prompt = generate_system_prompt(scenario)
      [{ role: "system", content: system_prompt }, { role: "user", content: scenario[:task] }]
    end

    def self.generate_system_prompt(scenario)
      tool_docs = scenario[:tools].call.map(&:to_tool_calling_prompt)
      prompts = Smolagents::Utilities::Prompts
      scenario[:agent_type] == :code ? prompts.code(tools: tool_docs) : prompts.agent(tools: tool_docs)
    end
  end

  # Analyzes model responses for compliance
  class ResponseAnalyzer
    def self.analyze(content, _scenario)
      return { status: :error, reason: "empty_response" } if content.nil? || content.empty?

      # Try to extract code using the library's pattern matching
      code = Smolagents::Utilities::PatternMatching.extract_code(content)

      if code
        { status: :pass, code:, has_final_answer: code.include?("final_answer") }
      else
        { status: :fail, reason: detect_failure_reason(content), raw: content[0..200] }
      end
    end

    def self.detect_failure_reason(content)
      return :direct_answer if content.match?(/\A[A-Z][^`<\[]*\z/m) # Plain text answer
      return :no_code_block if !content.include?("```") && !content.include?("<|")
      return :malformed_code if content.include?("```") && !content.match?(/```\w*\n/)

      :unknown_format
    end
  end

  # Test runner
  class Runner
    def initialize(options)
      @client = Client.new
      @models = filter_models(options[:model_filter])
      @iterations = options[:iterations]
      @results = []
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
      SCENARIOS.each do |name, scenario|
        @iterations.times do |i|
          result = run_single_test(model, name, scenario, i)
          @results << result
          print result[:status] == :pass ? "." : "F"
        end
      end
      puts
    end

    def run_single_test(model, scenario_name, scenario, iteration)
      messages = PromptBuilder.build(scenario)
      response, elapsed = timed_chat(model, messages)
      build_result(model, scenario_name, iteration, response, elapsed)
    end

    def timed_chat(model, messages)
      start = Time.now
      [{ model:, messages: }.then { |req| @client.chat(**req) }, Time.now - start]
    end

    def build_result(model, scenario_name, iteration, response, elapsed)
      content = response.dig("choices", 0, "message", "content")
      { model:, scenario: scenario_name, iteration:, elapsed: elapsed.round(2),
        prompt_tokens: response.dig("usage", "prompt_tokens"),
        **ResponseAnalyzer.analyze(content, nil) }
    end

    def print_summary
      puts "\n#{"=" * 70}\nRESULTS\n#{"=" * 70}"
      @results.group_by { |r| r[:model] }.each { |m, rs| print_model_result(m, rs) }
      save_results
    end

    def print_model_result(model, results)
      passed = results.count { |r| r[:status] == :pass }
      puts "#{model}: #{passed}/#{results.size} (#{(passed.to_f / results.size * 100).round(1)}%)"
      print_failures(results.select { |r| r[:status] == :fail })
    end

    def print_failures(failures)
      return unless failures.any?

      puts "  Failures: #{failures.group_by { |r| r[:reason] }.transform_values(&:size).inspect}"
    end

    def save_results
      File.write("script/compliance_results.json", JSON.pretty_generate({
                                                                          timestamp: Time.now.iso8601,
                                                                          summary: build_summary,
                                                                          results: @results
                                                                        }))
      puts "\nDetailed results saved to script/compliance_results.json"
    end

    def build_summary
      {
        total: @results.size,
        passed: @results.count { |r| r[:status] == :pass },
        failed: @results.count { |r| r[:status] == :fail },
        by_model: @results.group_by { |r| r[:model] }.transform_values do |rs|
          { passed: rs.count { |r| r[:status] == :pass }, total: rs.size }
        end
      }
    end
  end
end

# Parse options and run
options = { iterations: 5, model_filter: nil }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--model FILTER", "Filter models by name") { |v| options[:model_filter] = v }
  opts.on("--iterations N", Integer, "Iterations per scenario") { |v| options[:iterations] = v }
end.parse!

ModelComplianceTest::Runner.new(options).run
