#!/usr/bin/env ruby
# rubocop:disable Metrics
# Model Benchmark Test
#
# Runs tiered benchmark tests on LM Studio models using the library's
# ModelBenchmark infrastructure. Tests levels 1-5:
#   1. Basic Response - Can respond at all?
#   2. Code Format - Ruby code blocks?
#   3. Tool Calling - Single tool call?
#   4. Multi-Step - 2-3 step tasks?
#   5. Complex Reasoning - Multi-tool reasoning?
#
# Metacognition Strategies (--compare-strategies):
#   Tests four approaches to help models know when to stop:
#   - baseline: No modifications (control)
#   - planning: Pre-Act planning before execution
#   - goal_check: Goal detection prompt after each step
#   - strong_prompt: Explicit "call final_answer NOW" instructions
#   - more_steps: Increased max_steps (16 instead of 8)
#
# Usage:
#   ruby script/model_compliance_test.rb                    # All loaded models, 10 runs, 90% threshold
#   ruby script/model_compliance_test.rb --levels 1-3       # Run specific levels
#   ruby script/model_compliance_test.rb --timeout 120      # Timeout per test
#   ruby script/model_compliance_test.rb --runs 1           # Single run (quick test)
#   ruby script/model_compliance_test.rb --threshold 0.50   # Lower pass threshold
#   ruby script/model_compliance_test.rb --compare-strategies  # Test metacognition strategies
#
# Models are loaded dynamically from LM Studio - no model arguments needed.
#
# Results saved to script/results/ as individual files (never overwrites)

require "bundler/setup"
require "smolagents"
require "smolagents/testing"
require "smolagents/logging"
require "faraday"
require "fileutils"
require "json"
require "optparse"

module ModelComplianceTest
  RESULTS_DIR = "script/results".freeze
  LOGS_DIR = "script/logs".freeze
  API_BASE = "http://localhost:1234".freeze

  # Use tested RawOutputLogger for all model output logging
  def self.setup_logging
    @logger = Smolagents::Logging::RawOutputLogger.new(directory: LOGS_DIR)
    puts "Logging to: #{@logger.filepath}"
    @logger
  end

  def self.logger
    @logger
  end

  def self.close_logging
    return unless @logger

    puts "Logged #{@logger.entry_count} entries to #{@logger.filepath}"
    @logger.close
    @logger = nil
  end

  # Fetch available models from LM Studio API
  def self.fetch_models
    conn = Faraday.new(url: API_BASE) { |f| f.response :json }
    response = conn.get("/v1/models")
    response.body["data"].map { |m| m["id"] }.sort
  rescue StandardError => e
    warn "Failed to fetch models: #{e.message}"
    []
  end

  # Result storage - each result saved as individual file
  class ResultStore
    def initialize
      @session_results = []
      FileUtils.mkdir_p(RESULTS_DIR)
    end

    def add(model_id, result)
      data = {
        model: model_id,
        test_name: result.test_name,
        level: result.level,
        passed: result.passed?,
        duration: result.duration.round(2),
        error: result.error,
        steps: result.steps,
        metadata: result.respond_to?(:metadata) ? result.metadata : nil,
        timestamp: Time.now.iso8601
      }
      @session_results << data
      File.write(filepath(data), JSON.pretty_generate(data))
    end

    def filepath(data)
      ts = Time.now.strftime("%Y%m%d-%H%M%S")
      model = data[:model].tr("/", "_").tr(".", "-")
      test = data[:test_name].gsub(/[^a-zA-Z0-9_-]/, "_")
      status = data[:passed] ? "pass" : "fail"
      "#{RESULTS_DIR}/#{ts}_#{model}_L#{data[:level]}_#{test}_#{status}.json"
    end

    attr_reader :session_results
  end

  # Deterministic calculator tool for consistent testing
  def self.calculator_tool
    @calculator_tool ||= Smolagents::Tools.define_tool(
      "calculate",
      description: "Evaluate a math expression and return the numeric result.",
      inputs: { "expression" => { "type" => "string", "description" => "Math expression as string, e.g. '25 * 4'" } },
      output_type: "number"
    ) do |expression:|
      eval(expression).to_f # rubocop:disable Security/Eval
    rescue SyntaxError
      raise ArgumentError, "Invalid math expression. Use numbers and operators only: '8 * 5' not '8 hours * 5 days'"
    rescue NameError => e
      var = e.message.match(/undefined local variable or method [`'](\w+)[`']/)&.[](1)
      if var && expression.include?(var)
        raise NameError, "#{e.message}\n\nTIP: Pass literal string like '25 * 4', not variable names."
      end

      raise
    end
  end

  # Test runner using TieredTests with deterministic tools
  class Runner
    def initialize(options)
      @models = ModelComplianceTest.fetch_models
      @levels = options[:levels]
      @timeout = options[:timeout]
      @runs = options[:runs]
      @threshold = options[:threshold]
      @store = ResultStore.new
      @efficiency = EfficiencyTracker.new
    end

    def run
      puts header
      @models.each { |model| test_model(model) }
      print_summary
      save_efficiency_data
    end

    private

    def header
      reliability = @runs > 1 ? " | Runs: #{@runs} (#{(@threshold * 100).to_i}% threshold)" : ""
      <<~HEADER
        #{"=" * 70}
        Model Compliance Test - Tiered Testing (Levels #{@levels})
        Models: #{@models.size} | Timeout: #{@timeout}s#{reliability}
        #{"=" * 70}

      HEADER
    end

    def test_model(model_id)
      puts "=" * 70
      puts "TESTING: #{model_id}#{" (#{@runs} runs per test)" if @runs > 1}"
      puts "=" * 70

      max_level = 0
      tests_for_levels.each do |test_key, test_config|
        result = run_test_with_retries(model_id, test_key, test_config)
        @store.add(model_id, result)
        display_result(result)
        break unless result.passed?

        max_level = result.level
      end

      puts "  => Max level passed: #{max_level}"
      puts
    end

    def tests_for_levels
      TieredTests::TESTS.select do |key, _config|
        level = key.to_s.match(/l(\d+)/)[1].to_i
        @levels.include?(level)
      end
    end

    def run_test_with_retries(model_id, test_key, test_config)
      level = test_key.to_s.match(/l(\d+)/)[1].to_i
      return run_single_test(model_id, level, test_config) if @runs == 1

      attempts = []
      @runs.times { attempts << run_single_test(model_id, level, test_config) }
      aggregate_results(model_id, level, test_config, attempts)
    end

    def run_single_test(model_id, level, test_config)
      model = build_model(model_id)
      tools = test_config[:needs_tools] ? [ModelComplianceTest.calculator_tool] : []
      agent = Smolagents::Agents::Agent.new(model:, tools:, max_steps: test_config[:max_steps])

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = agent.run(test_config[:task])
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      passed = result.success? && test_config[:validate].call(result.output)
      error = if result.max_steps?
                "Max steps reached"
              else
                (if passed
                   nil
                 else
                   "Validation failed: #{result.output.to_s[0,
                                                            50]}"
                 end)
              end

      # Log raw outputs for analysis
      log_raw_output(model_id, level, test_config, result, passed, error)

      @efficiency.record(model: model_id, test: test_config[:name], steps_used: result.step_count,
                         max_steps: test_config[:max_steps], passed:)

      TestResult.new(level:, test_name: test_config[:name], passed:, duration:, steps: result.step_count, error:)
    rescue StandardError => e
      TestResult.new(level:, test_name: test_config[:name], passed: false, duration: 0, steps: 0,
                     error: "#{e.class}: #{e.message}")
    end

    def log_raw_output(model_id, level, test_config, result, passed, error)
      return unless ModelComplianceTest.logger

      raw_steps = result.steps.filter_map do |step|
        next unless step.respond_to?(:model_output_message) || step.respond_to?(:model_output)

        {
          step_type: step.class.name.split("::").last,
          step_number: step.respond_to?(:step_number) ? step.step_number : nil,
          model_output: step.respond_to?(:model_output_message) ? step.model_output_message&.content : nil,
          code_action: step.respond_to?(:code_action) ? step.code_action : nil,
          observations: step.respond_to?(:observations) ? step.observations : nil,
          action_output: step.respond_to?(:action_output) ? step.action_output : nil,
          error: step.respond_to?(:error) ? step.error : nil,
          is_final_answer: step.respond_to?(:is_final_answer) ? step.is_final_answer : nil
        }
      end

      ModelComplianceTest.logger.log_run(
        model_id:,
        config: "L#{level}: #{test_config[:name]}",
        data: {
          task: test_config[:task],
          success: passed,
          error:,
          step_count: result.step_count,
          final_output: result.output,
          raw_steps:
        }
      )
    end

    def aggregate_results(_model_id, level, test_config, attempts)
      passed_count = attempts.count(&:passed?)
      pass_rate = passed_count.to_f / attempts.size
      passed = pass_rate >= @threshold
      avg_duration = attempts.sum(&:duration) / attempts.size
      avg_steps = attempts.sum(&:steps) / attempts.size.to_f

      error = passed ? nil : "#{passed_count}/#{attempts.size} passed: #{attempts.reject(&:passed?).first&.error}"
      TestResult.new(level:, test_name: test_config[:name], passed:, duration: avg_duration, steps: avg_steps.round,
                     error:, metadata: { pass_rate:, runs: attempts.size })
    end

    def build_model(model_id)
      Smolagents::Models::OpenAIModel.new(
        model_id:,
        api_base: "#{API_BASE}/v1",
        api_key: "not-needed",
        timeout: @timeout
      )
    end

    def display_result(result)
      status = result.passed? ? "PASS" : "FAIL"
      reliability = result.metadata&.dig(:pass_rate) ? " (#{(result.metadata[:pass_rate] * 100).to_i}%)" : ""
      puts "  [#{status}] L#{result.level}: #{result.test_name} (#{result.duration.round(2)}s)#{reliability}"
      puts "         Error: #{result.error}" unless result.passed?
    end

    def print_summary
      puts "=" * 70
      puts "SUMMARY"
      puts "=" * 70

      @store.session_results.group_by { |r| r[:model] }.each do |model, results|
        passed = results.count { |r| r[:passed] }
        max_level = results.select { |r| r[:passed] }.map { |r| r[:level] }.max || 0
        puts "#{model}: #{passed}/#{results.size} passed, max level: #{max_level}"
      end

      puts "\nEfficiency:"
      puts @efficiency.summary
      puts "\nResults saved to #{RESULTS_DIR}/"
    end

    def save_efficiency_data
      ts = Time.now.strftime("%Y%m%d-%H%M%S")
      @efficiency.save("#{RESULTS_DIR}/#{ts}_efficiency.json")
    end
  end

  # Simple test result for internal use
  TestResult = Data.define(:level, :test_name, :passed, :duration, :steps, :error, :metadata) do
    def initialize(level:, test_name:, passed:, duration:, steps:, error: nil, metadata: nil)
      super
    end

    def passed? = passed
  end

  # Tiered test levels - build up from simple to complex
  #
  # L0: Basic Response - Can the model respond at all?
  # L1: Sandbox Basics - Can the model write and execute Ruby code?
  # L2: Single Tool - Can the model call a tool with correct params?
  # L3: Tool + Arithmetic - Can the model do math on tool results?
  # L4: Two Tool Calls - Can the model chain tool calls?
  # L5: Multi-Step Chain - Can the model follow numbered instructions?
  # L6: World Knowledge - Can the model apply context to calculations?
  # L7: Error Recovery - Can the model recover from mistakes?
  # L8: Self-Discovery - Can the model figure out tools with minimal hints?
  #
  module TieredTests
    TESTS = {
      l0_basic_response: {
        name: "L0: Basic Response",
        task: "Your only task: call final_answer(answer: 'Hello!'). Nothing else needed.",
        validate: ->(output) { output.to_s.downcase.match?(/hello|hi|hey|greetings/) },
        max_steps: 4,
        needs_tools: false,
        needs_sandbox: true
      },
      l1_sandbox_basics: {
        name: "L1: Sandbox Basics",
        task: "Write Ruby code that calculates 2 + 2 and returns the result with final_answer(answer: 4)",
        validate: ->(output) { output.to_s.include?("4") },
        max_steps: 3,
        needs_tools: false,
        needs_sandbox: true
      },
      l2_single_tool: {
        name: "L2: Single Tool",
        task: "Calculate 25 * 4 using the calculate tool and return the result with final_answer",
        validate: ->(output) { output.to_s.include?("100") },
        max_steps: 4,
        needs_tools: true
      },
      l3_tool_arithmetic: {
        name: "L3: Tool + Arithmetic",
        task: "Calculate 25 * 4 using calculate, then subtract 50 from the result " \
              "(directly, not with calculate), and return with final_answer",
        validate: ->(output) { output.to_s.include?("50") },
        max_steps: 4,
        needs_tools: true
      },
      l4_two_tools: {
        name: "L4: Two Tool Calls",
        task: "Calculate 100 / 4 using calculate, then calculate that result * 10 " \
              "using calculate again, and return with final_answer",
        validate: ->(output) { output.to_s.include?("250") },
        max_steps: 6,
        needs_tools: true
      },
      l5_chained: {
        name: "L5: Multi-Step Chain",
        task: <<~TASK.strip,
          Solve this step by step:
          1. First, calculate 25 * 4 using the calculate tool
          2. Then, subtract 50 from that result using the calculate tool
          3. Return the final number with final_answer
        TASK
        validate: ->(output) { output.to_s.include?("50") },
        max_steps: 8,
        needs_tools: true
      },
      l6_world_knowledge: {
        name: "L6: World Knowledge + Math",
        task: <<~TASK.strip,
          Someone works 8 hours per day for 5 days.
          Calculate the total hours using the calculate tool and return with final_answer.
        TASK
        validate: ->(output) { output.to_s.include?("40") },
        max_steps: 5,
        needs_tools: true
      },
      l7_error_recovery: {
        name: "L7: Error Recovery",
        task: <<~TASK.strip,
          Calculate 144 / 12 using calculate. If you make a mistake, try again.
          Return the result with final_answer.
        TASK
        validate: ->(output) { output.to_s.include?("12") },
        max_steps: 6,
        needs_tools: true
      },
      l8_self_discovery: {
        name: "L8: Self-Discovery",
        task: "What is 15 squared? Use the tools available and return the answer.",
        validate: ->(output) { output.to_s.include?("225") },
        max_steps: 5,
        needs_tools: true
      }
    }.freeze

    # Test variants probe specific dimensions at each level
    VARIANTS = {
      # L3 variants: Different mathematical operations
      l3v_division: {
        name: "L3v: Division Chain",
        task: "Calculate 1000 / 10 using calculate, then divide that by 5 using calculate, return with final_answer",
        validate: ->(output) { output.to_s.include?("20") },
        max_steps: 6,
        needs_tools: true
      },
      l3v_mixed_ops: {
        name: "L3v: Mixed Operations",
        task: "Calculate 50 + 25 using calculate, then multiply that by 2 using calculate, return with final_answer",
        validate: ->(output) { output.to_s.include?("150") },
        max_steps: 6,
        needs_tools: true
      },
      # L4 variants: Different instruction styles
      l4v_numbered: {
        name: "L4v: Numbered Steps",
        task: <<~TASK.strip,
          Follow these steps exactly:
          Step 1: Use calculate to compute 12 * 5
          Step 2: Use calculate to add 40 to that result
          Step 3: Call final_answer with the result
        TASK
        validate: ->(output) { output.to_s.include?("100") },
        max_steps: 8,
        needs_tools: true
      },
      l4v_narrative: {
        name: "L4v: Narrative Style",
        task: <<~TASK.strip,
          First, multiply 15 by 4 using the calculate tool.
          Next, subtract 10 from that result using calculate.
          Finally, return the answer with final_answer.
        TASK
        validate: ->(output) { output.to_s.include?("50") },
        max_steps: 8,
        needs_tools: true
      }
    }.freeze
  end

  # Efficiency tracking - measures steps used vs max_steps
  class EfficiencyTracker
    def initialize
      @data = []
    end

    def record(model:, test:, steps_used:, max_steps:, passed:)
      efficiency = passed ? (1.0 - (steps_used.to_f / max_steps)).round(3) : 0.0
      @data << { model:, test:, steps_used:, max_steps:, efficiency:, passed: }
    end

    def summary
      return "No data" if @data.empty?

      by_model = @data.group_by { |d| d[:model] }
      by_model.map do |model, runs|
        passed = runs.select { |r| r[:passed] }
        avg_eff = passed.empty? ? 0 : (passed.sum { |r| r[:efficiency] } / passed.size).round(3)
        "#{model}: avg_efficiency=#{avg_eff} (#{passed.size}/#{runs.size} passed)"
      end.join("\n")
    end

    def to_json(*_args)
      JSON.pretty_generate({
                             timestamp: Time.now.iso8601,
                             summary: @data.group_by { |d| d[:model] }.transform_values do |runs|
                               passed = runs.select { |r| r[:passed] }
                               {
                                 total_runs: runs.size,
                                 passed: passed.size,
                                 avg_efficiency: if passed.empty?
                                                   0
                                                 else
                                                   (passed.sum do |r|
                                                     r[:efficiency]
                                                   end / passed.size).round(3)
                                                 end,
                                 avg_steps: if passed.empty?
                                              0
                                            else
                                              (passed.sum do |r|
                                                r[:steps_used]
                                              end / passed.size.to_f).round(2)
                                            end
                               }
                             end,
                             raw_data: @data
                           })
    end

    def save(filename)
      File.write(filename, to_json)
    end
  end

  # Metacognition Strategy Comparison
  # Tests different approaches to help models know when to stop
  module MetacognitionStrategies
    TASK = TieredTests::TESTS[:l5_chained][:task]

    STRATEGIES = {
      baseline: {
        name: "Baseline",
        description: "No modifications (control)",
        max_steps: 8,
        planning_interval: nil,
        custom_instructions: nil
      },
      planning: {
        name: "Pre-Act Planning",
        description: "Planning step before execution",
        max_steps: 8,
        planning_interval: 3,
        custom_instructions: <<~INST.strip
          IMPORTANT: Code blocks must contain VALID RUBY ONLY. No labels like "step 1:" inside code.
          Put step numbers in your Thought, not in code.
        INST
      },
      goal_check: {
        name: "Goal Detection",
        description: "Explicit goal check in instructions",
        max_steps: 8,
        planning_interval: nil,
        custom_instructions: <<~INST.strip
          CRITICAL: After EACH tool call, ask yourself: "Do I now have the final answer?"
          If YES: Call final_answer IMMEDIATELY. Do not make additional tool calls.
          If NO: Continue with the next step.
        INST
      },
      strong_prompt: {
        name: "Strong Prompt",
        description: "Explicit urgency to call final_answer",
        max_steps: 8,
        planning_interval: nil,
        custom_instructions: <<~INST.strip
          WARNING: You have LIMITED steps. When you compute the final result, you MUST
          call final_answer(answer: <result>) IMMEDIATELY. Do NOT verify, recalculate,
          or make additional tool calls. Trust your calculation and commit to the answer.
        INST
      },
      more_steps: {
        name: "More Steps",
        description: "Increased max_steps (16 instead of 8)",
        max_steps: 16,
        planning_interval: nil,
        custom_instructions: nil,
        evaluation_enabled: false
      },
      evaluation: {
        name: "Evaluation",
        description: "Structured evaluation phase after each step",
        max_steps: 8,
        planning_interval: nil,
        custom_instructions: nil,
        evaluation_enabled: true
      }
    }.freeze

    def self.calculator_tool
      @calculator_tool ||= Smolagents::Tools.define_tool(
        "calculate",
        description: "Evaluate a math expression string and return the numeric result.",
        inputs: {
          "expression" => {
            "type" => "string",
            "description" => "Math expression as a string literal, e.g. '25 * 4'."
          }
        },
        output_type: "number"
      ) do |expression:|
        eval(expression).to_f # rubocop:disable Security/Eval
      rescue NameError => e
        var = e.message.match(/undefined local variable or method [`'](\w+)[`']/)&.[](1)
        if var && expression.include?(var)
          raise NameError, "#{e.message}\n\nTIP: Pass literal string like '25 * 4', not variable names."
        end

        raise
      end
    end
  end

  # Runner for metacognition strategy comparison
  class StrategyComparisonRunner
    include MetacognitionStrategies

    def initialize(options)
      @models = ModelComplianceTest.fetch_models
      @runs = options[:runs]
      @threshold = options[:threshold]
      @timeout = options[:timeout]
      @results = Hash.new { |h, k| h[k] = {} }
      FileUtils.mkdir_p(RESULTS_DIR)
    end

    def run
      puts header
      @models.each { |model| test_model_strategies(model) }
      print_comparison
      save_comparison
    end

    private

    def header
      <<~HEADER
        #{"=" * 70}
        Metacognition Strategy Comparison
        Models: #{@models.size} | Runs: #{@runs} | Threshold: #{(@threshold * 100).to_i}%
        Task: Multi-step calculation (L4)
        #{"=" * 70}

      HEADER
    end

    def test_model_strategies(model_id)
      puts "=" * 70
      puts "MODEL: #{model_id}"
      puts "=" * 70

      STRATEGIES.each do |key, config|
        print "  #{config[:name].ljust(20)}: "
        result = test_strategy(model_id, key, config)
        @results[model_id][key] = result
        display_strategy_result(result)
      end
      puts
    end

    def test_strategy(model_id, strategy_key, config)
      passes = 0
      total_steps = 0
      total_duration = 0.0
      errors = []

      @runs.times do |_i|
        result = run_single_test(model_id, config)
        if result[:success]
          passes += 1
        else
          errors << result[:error]
        end
        total_steps += result[:steps]
        total_duration += result[:duration]
      end

      {
        strategy: strategy_key,
        passes:,
        runs: @runs,
        pass_rate: passes.to_f / @runs,
        passed: (passes.to_f / @runs) >= @threshold,
        avg_steps: (total_steps.to_f / @runs).round(2),
        avg_duration: (total_duration / @runs).round(2),
        errors: errors.uniq.first(3)
      }
    end

    def run_single_test(model_id, config)
      model = build_model(model_id)
      agent = build_agent(model, config)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = agent.run(TASK)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      success = result.success? && result.output.to_s.include?("50")
      error = if result.max_steps?
                "Max steps reached"
              elsif !result.output.to_s.include?("50")
                "Wrong answer: #{result.output.to_s[0, 50]}"
              end

      # Extract raw outputs from steps in result (handle different step types)
      raw_steps = result.steps.filter_map do |step|
        # Skip steps without model output
        next unless step.respond_to?(:model_output_message) || step.respond_to?(:model_output)

        {
          step_type: step.class.name.split("::").last,
          step_number: safe_call(step, :step_number),
          model_output: safe_call(step, :model_output_message)&.content || safe_call(step, :model_output),
          code_action: safe_call(step, :code_action),
          observations: safe_call(step, :observations),
          action_output: safe_call(step, :action_output),
          error: safe_call(step, :error),
          is_final_answer: safe_call(step, :is_final_answer)
        }
      end

      # LOG RAW OUTPUTS USING TESTED LOGGER
      ModelComplianceTest.logger&.log_run(
        model_id:,
        config: config[:name] || "default",
        data: {
          task: TASK,
          success:,
          error:,
          step_count: result.step_count,
          final_output: result.output,
          raw_steps:
        }
      )

      { success:, steps: result.step_count, duration:, error: }
    rescue StandardError => e
      ModelComplianceTest.logger&.log_error(
        model_id:,
        error: e,
        context: { config: config[:name] || "default" }
      )
      { success: false, steps: 0, duration: 0, error: "#{e.class}: #{e.message}" }
    end

    # Safe method call - returns nil if method doesn't exist
    def safe_call(obj, method)
      obj.respond_to?(method) ? obj.send(method) : nil
    end

    def build_model(model_id)
      Smolagents::Models::OpenAIModel.new(
        model_id:,
        api_base: "#{API_BASE}/v1",
        api_key: "not-needed",
        timeout: @timeout
      )
    end

    def build_agent(model, config)
      Smolagents::Agents::Agent.new(
        model:,
        tools: [MetacognitionStrategies.calculator_tool],
        max_steps: config[:max_steps],
        planning_interval: config[:planning_interval],
        custom_instructions: config[:custom_instructions],
        evaluation_enabled: config[:evaluation_enabled] || false
      )
    end

    def display_strategy_result(result)
      status = result[:passed] ? "PASS" : "FAIL"
      puts "#{result[:passes]}/#{result[:runs]} (#{(result[:pass_rate] * 100).to_i}%) " \
           "[#{status}] avg_steps=#{result[:avg_steps]} avg_time=#{result[:avg_duration]}s"
      result[:errors].each { |e| puts "    └─ #{e}" } unless result[:passed]
    end

    def print_comparison
      puts "=" * 70
      puts "COMPARISON SUMMARY"
      puts "=" * 70

      # Header
      puts
      puts "Model".ljust(35) + STRATEGIES.keys.map { |k| STRATEGIES[k][:name][0, 10].center(12) }.join
      puts "-" * (35 + (STRATEGIES.size * 12))

      # Results per model
      @results.each do |model, strategies|
        row = model[0, 34].ljust(35)
        STRATEGIES.each_key do |key|
          r = strategies[key]
          cell = r ? "#{(r[:pass_rate] * 100).to_i}%".center(12) : "N/A".center(12)
          row += cell
        end
        puts row
      end

      # Winner per model
      puts
      puts "WINNERS:"
      @results.each do |model, strategies|
        best = strategies.max_by { |_, r| [r[:pass_rate], -r[:avg_steps]] }
        puts "  #{model[0, 40]}: #{STRATEGIES[best[0]][:name]} (#{(best[1][:pass_rate] * 100).to_i}%)" if best
      end
    end

    def save_comparison
      ts = Time.now.strftime("%Y%m%d-%H%M%S")
      filename = "#{RESULTS_DIR}/#{ts}_strategy_comparison.json"
      File.write(filename, JSON.pretty_generate({
                                                  timestamp: Time.now.iso8601,
                                                  models: @models,
                                                  runs: @runs,
                                                  threshold: @threshold,
                                                  results: @results
                                                }))
      puts "\nComparison saved to #{filename}"
    end
  end
end

# Parse options and run
options = { levels: 1..5, timeout: 120, runs: 10, threshold: 0.90, compare_strategies: false }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--levels RANGE", "Test levels to run (e.g., 1-3 or 1..5)") do |v|
    parts = v.split(/[-.]/).map(&:to_i)
    options[:levels] = parts[0]..parts[-1]
  end
  opts.on("--timeout SECS", Integer, "Timeout per test (default: 120)") { |v| options[:timeout] = v }
  opts.on("--runs N", Integer, "Runs per test for reliability (default: 10)") { |v| options[:runs] = v }
  opts.on("--threshold PCT", Float, "Pass threshold as decimal (default: 0.90)") { |v| options[:threshold] = v }
  opts.on("--compare-strategies", "Run metacognition strategy comparison") { options[:compare_strategies] = true }
end.parse!

ModelComplianceTest.setup_logging
begin
  if options[:compare_strategies]
    ModelComplianceTest::StrategyComparisonRunner.new(options).run
  else
    ModelComplianceTest::Runner.new(options).run
  end
ensure
  ModelComplianceTest.close_logging
  puts "\nRaw outputs saved to script/logs/"
end
