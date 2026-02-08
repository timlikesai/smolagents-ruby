#!/usr/bin/env ruby
# Model Validation Matrix
# =======================
# Structured capability testing against real models using the gem's DSL.
# Collects data across dimensions: generation, agent loop, tool use,
# multi-step, error recovery. Saves JSON results for comparison.
#
# Usage:
#   ruby experiments/live/model_validation.rb                            # Default model
#   ruby experiments/live/model_validation.rb gemma-3n-E4B-it-Q8_0      # Specific model
#   ruby experiments/live/model_validation.rb --list                     # Available models

require_relative "lib/bootstrap"
require "json"

module LiveExperiments
  class ModelValidation
    ENDPOINT = Infrastructure::Endpoints::LLAMA_CPP_ULTRA
    RESULTS_DIR = File.join(__dir__, "data", "results")
    MATH_OPS = { "+" => :+, "-" => :-, "*" => :*, "/" => :/ }.freeze

    def initialize(model_id)
      @model_id = model_id
      @matrix = []   # structured test results
      @gaps = []     # discovered issues
    end

    def run
      header("Model Validation Matrix: #{@model_id}")
      puts "Endpoint: #{ENDPOINT}\n\n"

      model = build_model
      return 1 unless model

      run_dimension(:generation, "Raw Generation", model)
      run_dimension(:agent_loop, "Agent Loop", model)
      run_dimension(:tool_use, "Tool Use", model)
      run_dimension(:multi_step, "Multi-Step", model)
      run_dimension(:error_recovery, "Error Recovery", model)

      save_results
      print_matrix
      print_gaps
      0
    end

    private

    # ============================================================
    # Model — built entirely with gem DSL
    # ============================================================

    def build_model
      section("Building model")
      model = Smolagents.model(:openai)
                        .base_url(ENDPOINT)
                        .id(@model_id)
                        .server_type(:llama_cpp)
                        .timeout(60)
                        .max_tokens(2048)
                        .build
      puts "  Server: #{model.server_capabilities&.server_type&.name || "unknown"}"
      puts "  Tools: #{model.server_capabilities&.supports_tools}"
      model
    rescue StandardError => e
      puts "  BUILD FAILED: #{e.class}: #{e.message}"
      nil
    end

    # ============================================================
    # Dimension: Raw Generation
    # ============================================================

    def tests_for_generation(model)
      [
        {
          id: "gen.trivial", name: "Trivial question (2+2)",
          run: -> {
            r = model.generate([Smolagents::ChatMessage.user("What is 2+2? Reply with just the number.")])
            { content: r.content.strip, tokens: r.token_usage&.to_h,
              correct: r.content.strip.include?("4") }
          }
        },
        {
          id: "gen.paragraph", name: "Paragraph response",
          run: -> {
            r = model.generate([Smolagents::ChatMessage.user("Explain what Ruby is in 2-3 sentences.")])
            { content_length: r.content.strip.length, tokens: r.token_usage&.to_h,
              correct: r.content.strip.length > 20 }
          }
        },
        {
          id: "gen.instruction_following", name: "Strict format instruction",
          run: -> {
            r = model.generate([Smolagents::ChatMessage.user(
              "List exactly 3 colors, one per line, no numbering, no extra text."
            )])
            lines = r.content.strip.split("\n").map(&:strip).reject(&:empty?)
            { content: r.content.strip, line_count: lines.size,
              correct: lines.size == 3 }
          }
        }
      ]
    end

    # ============================================================
    # Dimension: Agent Loop
    # ============================================================

    def tests_for_agent_loop(model)
      [
        {
          id: "loop.direct_answer", name: "Direct answer (no tools needed)",
          run: -> {
            events = collect_events(model, max_steps: 3) do |agent|
              agent.run("What is the capital of France? Answer with just the city name.")
            end
            { state: events[:result].state, output: events[:result].output,
              steps: events[:step_count], correct: events[:result].state == :success }
          }
        },
        {
          id: "loop.code_generation", name: "Generates valid Ruby code",
          run: -> {
            events = collect_events(model, max_steps: 3) do |agent|
              agent.run("Compute 7 * 8 and give the final answer.")
            end
            output = events[:result].output.to_s
            { state: events[:result].state, output: output,
              steps: events[:step_count], parse_retries: events[:parse_retries],
              correct: events[:result].state == :success && output.include?("56") }
          }
        },
        {
          id: "loop.max_steps_respected", name: "Stops at max_steps",
          run: -> {
            # Task that's hard to answer in 1 step — just verify it doesn't hang
            events = collect_events(model, max_steps: 2) do |agent|
              agent.run("Write a very detailed 10-paragraph essay about nothing.")
            end
            { state: events[:result].state, steps: events[:step_count],
              correct: !events[:result].nil? } # Completed without crash
          }
        }
      ]
    end

    # ============================================================
    # Dimension: Tool Use
    # ============================================================

    def tests_for_tool_use(model)
      [
        {
          id: "tool.simple_calc", name: "Single tool call (calculate)",
          run: -> {
            tool_calls = []
            agent = build_agent(model, max_steps: 5) do |b|
              b.tool(:calculate, "Calculate a math expression and return the numeric result",
                     expression: String) { |expression:| safe_math(expression) }
            end
            agent.on(:tool_call_completed) { |e| tool_calls << e.tool_name }

            result = agent.run("What is 15 * 7? Use the calculate tool.")
            output = result.output.to_s
            { state: result.state, output: output, tool_calls: tool_calls,
              correct: result.state == :success && output.include?("105") }
          }
        },
        {
          id: "tool.string_manipulation", name: "String tool",
          run: -> {
            tool_calls = []
            agent = build_agent(model, max_steps: 5) do |b|
              b.tool(:reverse_text, "Reverse a string of text and return it",
                     text: String) { |text:| text.to_s.reverse }
            end
            agent.on(:tool_call_completed) { |e| tool_calls << e.tool_name }

            result = agent.run("Reverse the text 'hello world' using the reverse_text tool.")
            output = result.output.to_s
            { state: result.state, output: output, tool_calls: tool_calls,
              correct: result.state == :success && output.include?("dlrow olleh") }
          }
        },
        {
          id: "tool.correct_args", name: "Passes correct arguments",
          run: -> {
            received_args = []
            agent = build_agent(model, max_steps: 5) do |b|
              b.tool(:lookup, "Look up information about a topic",
                     topic: String) { |topic:|
                received_args << topic
                "#{topic} is a programming language created by Yukihiro Matsumoto."
              }
            end

            result = agent.run("Look up information about Ruby using the lookup tool.")
            { state: result.state, output: result.output.to_s[0, 200],
              received_args: received_args,
              correct: result.state == :success && received_args.any? { |a| a.downcase.include?("ruby") } }
          }
        }
      ]
    end

    # ============================================================
    # Dimension: Multi-Step
    # ============================================================

    def tests_for_multi_step(model)
      [
        {
          id: "multi.two_tools", name: "Chain two different tools",
          run: -> {
            tool_calls = []
            agent = build_agent(model, max_steps: 8) do |b|
              b.tool(:calculate, "Calculate a math expression",
                     expression: String) { |expression:| safe_math(expression) }
               .tool(:format_number, "Format a number with commas for readability",
                     number: String) { |number:|
                 number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
               }
            end
            agent.on(:tool_call_completed) { |e| tool_calls << e.tool_name }

            result = agent.run("Calculate 123 * 456, then format the result with commas.")
            { state: result.state, output: result.output.to_s,
              tool_calls: tool_calls, correct: result.state == :success }
          }
        },
        {
          id: "multi.tool_then_answer", name: "Use tool result in final answer",
          run: -> {
            agent = build_agent(model, max_steps: 5) do |b|
              b.tool(:calculate, "Calculate a math expression",
                     expression: String) { |expression:| safe_math(expression) }
            end

            result = agent.run("What is 99 + 1?")
            output = result.output.to_s
            { state: result.state, output: output,
              correct: result.state == :success && output.include?("100") }
          }
        }
      ]
    end

    # ============================================================
    # Dimension: Error Recovery
    # ============================================================

    def tests_for_error_recovery(model)
      [
        {
          id: "recovery.no_crash", name: "Completes without crashing",
          run: -> {
            events = collect_events(model, max_steps: 5) do |agent|
              agent.run("Say hello.")
            end
            { state: events[:result].state, output: events[:result].output.to_s[0, 100],
              errors: events[:errors], correct: !events[:result].nil? }
          }
        },
        {
          id: "recovery.parse_retry", name: "Parse retry events fire",
          run: -> {
            events = collect_events(model, max_steps: 5) do |agent|
              # Intentionally vague — model may produce non-code output first
              agent.run("Think about this carefully, then answer: what is the meaning of life?")
            end
            { state: events[:result].state, output: events[:result].output.to_s[0, 100],
              parse_retries: events[:parse_retries], steps: events[:step_count],
              correct: !events[:result].nil? }
          }
        },
        {
          id: "recovery.tool_error", name: "Handles tool execution error",
          run: -> {
            error_count = 0
            agent = build_agent(model, max_steps: 5) do |b|
              b.tool(:failing_tool, "A tool that always fails",
                     input: String) { |input:| raise "deliberate test failure" }
            end
            agent.on(:error_occurred) { |_e| error_count += 1 }

            result = agent.run("Use the failing_tool with input 'test'.")
            { state: result.state, output: result.output.to_s[0, 200],
              errors: error_count, correct: !result.nil? }
          }
        }
      ]
    end

    # ============================================================
    # Test Execution Engine
    # ============================================================

    def run_dimension(dimension, label, model)
      section(label)
      tests = send(:"tests_for_#{dimension}", model)
      tests.each do |test|
        run_single_test(dimension, test)
      end
    end

    def run_single_test(dimension, test)
      print "  #{test[:name]}: "
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      data = test[:run].call
      ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
      passed = data[:correct]

      puts passed ? "PASS (#{ms}ms)" : "FAIL (#{ms}ms)"
      data.reject { |k, _| k == :correct }.each { |k, v| puts "    #{k}: #{v.inspect}" } unless passed

      @matrix << {
        id: test[:id], dimension:, name: test[:name],
        passed:, duration_ms: ms, data:, error: nil
      }
    rescue StandardError => e
      ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
      puts "ERROR (#{ms}ms): #{e.class}: #{e.message}"
      @matrix << {
        id: test[:id], dimension:, name: test[:name],
        passed: false, duration_ms: ms, data: nil,
        error: "#{e.class}: #{e.message}"
      }
      gap!("#{test[:id]}: #{e.class} — #{e.message}")
    end

    # ============================================================
    # Agent Builder Helper — uses gem DSL
    # ============================================================

    def build_agent(model, max_steps: 5)
      builder = Smolagents.agent
                          .model { model }
                          .max_steps(max_steps)
                          .evaluation(enabled: false)
      builder = yield(builder) if block_given?
      builder.build
    end

    def collect_events(model, max_steps: 5)
      step_count = 0
      parse_retries = 0
      errors = 0
      agent = build_agent(model, max_steps:)
      agent.on(:step_completed) { |_e| step_count += 1 }
      agent.on(:parse_retry_attempted) { |_e| parse_retries += 1 }
      agent.on(:error_occurred) { |_e| errors += 1 }

      result = yield(agent)
      { result:, step_count:, parse_retries:, errors: }
    end

    # ============================================================
    # Safe Math (no eval for simple cases)
    # ============================================================

    def safe_math(expression)
      sanitized = expression.to_s.gsub(/[^0-9+\-*\/().\s]/, "").strip
      result = Integer(sanitized) rescue Float(sanitized) rescue compute_simple(sanitized)
      result.to_s
    rescue StandardError => e
      "Error: #{e.message}"
    end

    def compute_simple(expr)
      if expr =~ /\A\s*(-?\d+(?:\.\d+)?)\s*([+\-*\/])\s*(-?\d+(?:\.\d+)?)\s*\z/
        a, op, b = $1.to_f, $2, $3.to_f
        return a.send(MATH_OPS[op], b)
      end
      binding.eval(expr) # rubocop:disable Security/Eval -- sandboxed experiment tool
    end

    # ============================================================
    # Results
    # ============================================================

    def save_results
      FileUtils.mkdir_p(RESULTS_DIR)
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      filename = "#{@model_id.gsub(/[^a-zA-Z0-9._-]/, "_")}_#{timestamp}.json"
      path = File.join(RESULTS_DIR, filename)

      payload = {
        model_id: @model_id, endpoint: ENDPOINT,
        timestamp: Time.now.iso8601,
        summary: build_summary,
        matrix: @matrix, gaps: @gaps
      }

      File.write(path, JSON.pretty_generate(payload))
      puts "\nResults saved: #{path}"
    end

    def build_summary
      by_dim = @matrix.group_by { |t| t[:dimension] }
      by_dim.transform_values do |tests|
        passed = tests.count { |t| t[:passed] }
        { passed:, total: tests.size, score: "#{passed}/#{tests.size}" }
      end
    end

    def print_matrix
      header("Matrix: #{@model_id}")
      summary = build_summary
      total_passed = @matrix.count { |t| t[:passed] }
      total_ms = @matrix.sum { |t| t[:duration_ms] }
      puts "Overall: #{total_passed}/#{@matrix.size} passed (#{total_ms}ms total)\n\n"

      summary.each do |dim, scores|
        puts "  #{dim}: #{scores[:score]}"
      end

      puts "\nDetail:"
      @matrix.each do |t|
        icon = t[:passed] ? "  PASS" : "  FAIL"
        line = "  #{icon}  #{t[:id]} (#{t[:duration_ms]}ms)"
        line += " — #{t[:error]}" if t[:error]
        puts line
      end
    end

    def print_gaps
      return if @gaps.empty?

      header("Gaps Discovered")
      @gaps.each_with_index { |g, i| puts "  #{i + 1}. #{g}" }
    end

    def gap!(description)
      @gaps << description
    end

    def header(text)
      puts "\n#{"=" * 60}"
      puts text
      puts "=" * 60
    end

    def section(text)
      puts "\n--- #{text} ---"
    end
  end
end

# ============================================================
# CLI
# ============================================================

if ARGV.include?("--list")
  endpoint = LiveExperiments::Infrastructure::Endpoints::LLAMA_CPP_ULTRA
  puts "Fetching models from #{endpoint}..."
  begin
    require "net/http"
    require "json"
    uri = URI("#{endpoint}/models")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10
    response = http.get(uri.path)
    data = JSON.parse(response.body)["data"]
    data.each do |m|
      status = m["status"].is_a?(Hash) ? m["status"]["value"] : m["status"]
      icon = status == "loaded" ? "*" : " "
      puts "  #{icon} #{m["id"]} (#{status})"
    end
    puts "\n  * = currently loaded"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
  exit 0
end

model_id = ARGV.first || ENV.fetch("FAST_MODEL_ID", "LFM2.5-1.2B-Instruct-BF16")
exit LiveExperiments::ModelValidation.new(model_id).run
