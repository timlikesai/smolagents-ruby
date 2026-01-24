# Mock model for dry run testing.
# Returns correct solutions for each test to verify the full pipeline.
# LOGS ALL RAW PROMPTS TO FILES for analysis.

require_relative "test_solutions"

module Reliability
  # A mock model that returns pre-defined correct solutions for tests.
  # Used for dry-run testing to debug the framework without model variance.
  # Logs ALL raw prompts to file for debugging.
  class DryRunModel
    attr_reader :model_id, :call_count, :calls
    attr_accessor :logger

    def initialize(verbose: false, logger: nil)
      @model_id = "dry-run-mock"
      @call_count = 0
      @calls = []
      @verbose = verbose
      @logger = logger

      # Inject solutions into test definitions
      TestSolutions.inject_solutions!
    end

    # Generate a response that solves the current task.
    # Behaves exactly like a real model - always returns code blocks.
    # LOGS THE FULL RAW PROMPT TO FILE.
    def generate(messages, **)
      @call_count += 1
      task = extract_task(messages)
      @calls << { task:, messages: messages.map { |m| summarize_message(m) } }

      # LOG THE FULL RAW PROMPT TO FILE
      log_raw_prompt(messages)

      code = resolve_code_for_task(task)
      response_text = "```ruby\n#{code}\n```"

      # LOG THE RAW RESPONSE TO FILE
      log_raw_response(response_text)

      Smolagents::Types::ChatMessage.assistant(response_text)
    end

    # Summary of all calls for debugging
    def call_summary
      @calls.map.with_index do |call, i|
        "Call #{i + 1}: #{call[:task]&.slice(0, 60)}..."
      end.join("\n")
    end

    private

    def resolve_code_for_task(task)
      test = find_test_for_task(task)
      return fallback_with_log(task, test) unless test

      code = extract_solution(test)
      return fallback_with_log(task, test) unless code

      log_solution(test[:name], code) if @verbose
      code
    end

    def extract_solution(test)
      solution = test[:solution]
      solution.is_a?(Hash) ? solution[:solution] : solution
    end

    def fallback_with_log(task, test)
      code = generate_fallback_solution(task, test)
      log_fallback(task, code) if @verbose
      code
    end

    def extract_task(messages)
      # Look for user message with task
      user_msg = messages.reverse.find do |m|
        role = m.respond_to?(:role) ? m.role : m[:role]
        role.to_s == "user"
      end

      return nil unless user_msg

      content = user_msg.respond_to?(:content) ? user_msg.content : user_msg[:content]
      content.to_s.strip
    end

    def summarize_message(msg)
      role = msg.respond_to?(:role) ? msg.role : msg[:role]
      content = msg.respond_to?(:content) ? msg.content : msg[:content]
      { role:, content_preview: content.to_s.slice(0, 100) }
    end

    def find_test_for_task(task)
      return nil unless task

      # Try exact match first
      TestDefinitions.all_tests.find do |test|
        task == test[:task]
      end || TestDefinitions.all_tests.find do |test|
        # Then try fuzzy match
        task.include?(test[:task]) || test[:task].include?(task)
      end
    end

    def generate_fallback_solution(task, test)
      if test&.dig(:expect)
        # Simple case: just return the expected value
        value = test[:expect]
        if value.match?(/^\d+$/)
          "final_answer(answer: #{value})"
        else
          "final_answer(answer: #{value.inspect})"
        end
      else
        # No solution available
        "# DRY RUN: No pre-defined solution\n# Task: #{task}\nfinal_answer(answer: 'dry-run-needs-solution')"
      end
    end

    def log_solution(name, code)
      puts "  [DRY RUN] Using solution for '#{name}'"
      puts "  #{code.lines.first.strip}..."
    end

    def log_fallback(task, _code)
      puts "  [DRY RUN] Using fallback for: #{task&.slice(0, 40)}..."
    end

    # Log the FULL raw prompt to file - every message, full content
    def log_raw_prompt(messages)
      return unless @logger

      @logger.subsection("RAW PROMPT SENT TO MODEL")
      messages.each_with_index { |msg, i| log_single_message(msg, i + 1) }
    end

    def log_single_message(msg, num)
      role = msg.respond_to?(:role) ? msg.role : msg[:role]
      content = msg.respond_to?(:content) ? msg.content : msg[:content]
      @logger.info("=== MESSAGE #{num} [#{role}] ===")
      content.to_s.each_line { |line| @logger.info(line.chomp) }
      @logger.info("=== END MESSAGE #{num} ===")
    end

    # Log the raw response to file
    def log_raw_response(response_text)
      return unless @logger

      @logger.subsection("RAW MODEL RESPONSE")
      response_text.each_line { |line| @logger.info(line.chomp) }
      @logger.info("=== END RESPONSE ===")
    end
  end
end
