#!/usr/bin/env ruby
# Agent Failure Mode Exploration
# ==============================
# Systematically test agent behavior to understand limitations and failure modes.
#
# Run with: ruby exploration/agent_failure_modes.rb
#
# Categories of tests:
# 1. Fact retrieval (specific answers exist)
# 2. Ambiguous queries (multiple valid interpretations)
# 3. Multi-step reasoning (requires combining info)
# 4. Tool failure handling (when searches fail)
# 5. Hallucination triggers (when model makes things up)
# 6. Temporal queries (current vs historical info)

require "bundler/setup"
require "smolagents"
require "json"
require "fileutils"

class AgentExplorer
  RESULTS_DIR = File.expand_path("results", __dir__)

  def initialize(model_name: "gemma-3n-e4b")
    @model = Smolagents::OpenAIModel.lm_studio(model_name)
    @results = []
    FileUtils.mkdir_p(RESULTS_DIR)
  end

  def run_test(name:, query:, category:, expected: nil, notes: nil)
    puts "\n#{"=" * 60}"
    puts "TEST: #{name}"
    puts "CATEGORY: #{category}"
    puts "QUERY: #{query}"
    puts "EXPECTED: #{expected || "(open-ended)"}"
    puts "-" * 60

    tool_calls = []
    tool_results = []
    errors = []
    steps = 0

    agent = Smolagents.agent
                      .model { @model }
                      .tools(:search)
                      .max_steps(8)
                      .on(:tool_call) { |e| tool_calls << { tool: e.tool_name, args: e.args } }
                      .on(:tool_complete) { |e| tool_results << { tool: e.tool_name, result: e.result.to_s[0..200] } }
                      .on(:step_complete) { |_e| steps += 1 }
                      .on(:error) { |e| errors << { type: e.error_class, message: e.error_message.to_s[0..100] } }
                      .build

    start_time = Time.now
    begin
      result = agent.run(query)
      output = result.output
      status = :completed
    rescue StandardError => e
      output = nil
      status = :error
      errors << { type: e.class.name, message: e.message[0..200] }
    end
    elapsed = Time.now - start_time

    # Analyze result
    analysis = analyze_result(output, expected, tool_calls, errors)

    record = {
      name:,
      category:,
      query:,
      expected:,
      output:,
      status:,
      steps:,
      tool_calls:,
      tool_results:,
      errors:,
      elapsed_seconds: elapsed.round(2),
      analysis:,
      notes:
    }

    @results << record
    print_result(record)
    record
  end

  def analyze_result(output, expected, tool_calls, errors)
    analysis = {
      has_output: !output.nil? && !output.empty?,
      tool_count: tool_calls.size,
      had_errors: errors.any?,
      failure_modes: []
    }

    # Check for common failure modes
    if output.nil? || output.empty?
      analysis[:failure_modes] << :no_output
    elsif expected
      if output.downcase.include?(expected.downcase)
        analysis[:correct] = true
      else
        analysis[:correct] = false
        analysis[:failure_modes] << :wrong_answer
      end
    end

    # Detect potential hallucination markers
    hallucination_phrases = [
      "I don't have", "I cannot", "I'm unable", "not available",
      "I apologize", "I don't know", "couldn't find"
    ]
    if output && hallucination_phrases.none? { |p| output.downcase.include?(p.downcase) } && tool_calls.empty?
      # Output is confident - check if it might be hallucinated
      analysis[:failure_modes] << :answered_without_tools
    end

    # Check for incomplete tool usage
    analysis[:failure_modes] << :rate_limited if errors.any? { |e| e[:type].to_s.include?("RateLimit") }

    # Check if model gave up too early
    if output&.include?("not explicitly provided") || output&.include?("not available")
      analysis[:failure_modes] << :gave_up_early
    end

    analysis
  end

  def print_result(record)
    puts "\nRESULT:"
    puts "  Status: #{record[:status]}"
    puts "  Steps: #{record[:steps]}"
    puts "  Tools called: #{record[:tool_calls].map { |t| t[:tool] }.join(", ")}"
    puts "  Errors: #{record[:errors].map { |e| e[:type] }.join(", ")}" if record[:errors].any?
    puts "  Output: #{record[:output]&.slice(0, 200)}..."
    puts "  Analysis: #{record[:analysis][:failure_modes].join(", ")}" if record[:analysis][:failure_modes].any?
    puts "  Time: #{record[:elapsed_seconds]}s"
  end

  def save_results(filename = "exploration_#{Time.now.strftime("%Y%m%d_%H%M%S")}.json")
    path = File.join(RESULTS_DIR, filename)
    File.write(path, JSON.pretty_generate(@results))
    puts "\nResults saved to: #{path}"

    # Also generate summary
    generate_summary
  end

  def generate_summary
    puts "\n#{"=" * 60}"
    puts "EXPLORATION SUMMARY"
    puts "=" * 60

    by_category = @results.group_by { |r| r[:category] }
    by_category.each do |category, tests|
      puts "\n#{category.upcase}:"
      tests.each do |t|
        status = if t[:analysis][:correct] == true
                   "✓"
                 else
                   t[:analysis][:correct] == false ? "✗" : "?"
                 end
        modes = t[:analysis][:failure_modes]
        puts "  #{status} #{t[:name]}: #{modes.any? ? modes.join(", ") : "ok"}"
      end
    end

    # Failure mode statistics
    all_modes = @results.flat_map { |r| r[:analysis][:failure_modes] }
    return unless all_modes.any?

    puts "\nFAILURE MODE FREQUENCY:"
    all_modes.tally.sort_by { |_, v| -v }.each do |mode, count|
      puts "  #{mode}: #{count}"
    end
  end
end

# =============================================================================
# TEST DEFINITIONS
# =============================================================================

explorer = AgentExplorer.new

# -----------------------------------------------------------------------------
# CATEGORY 1: Specific Fact Retrieval
# These have definite correct answers
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "NYT Street Address",
  query: "What is the street address of the New York Times headquarters?",
  expected: "620 Eighth Avenue",
  category: :fact_retrieval,
  notes: "Known issue: Wikipedia article about NYT doesn't include address, need to find Building article"
)

explorer.run_test(
  name: "Ruby Creator",
  query: "Who created the Ruby programming language?",
  expected: "Yukihiro Matsumoto",
  category: :fact_retrieval,
  notes: "Should be easy - well-documented fact"
)

explorer.run_test(
  name: "Specific Date",
  query: "What year was the Eiffel Tower completed?",
  expected: "1889",
  category: :fact_retrieval,
  notes: "Simple historical fact"
)

explorer.run_test(
  name: "Company Founder",
  query: "Who founded Amazon?",
  expected: "Jeff Bezos",
  category: :fact_retrieval,
  notes: "Well-known fact, should be in Wikipedia"
)

# -----------------------------------------------------------------------------
# CATEGORY 2: Ambiguous Queries
# Multiple valid interpretations possible
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "Ambiguous 'Apple'",
  query: "Tell me about Apple",
  expected: nil, # Could be fruit or company
  category: :ambiguous,
  notes: "Model must choose interpretation or ask for clarification"
)

explorer.run_test(
  name: "The Office",
  query: "Who plays the main character in The Office?",
  expected: nil, # US vs UK version
  category: :ambiguous,
  notes: "Steve Carell (US) or Ricky Gervais (UK) - both valid"
)

explorer.run_test(
  name: "Capital City",
  query: "What is the capital?",
  expected: nil,
  category: :ambiguous,
  notes: "Missing context - capital of what?"
)

# -----------------------------------------------------------------------------
# CATEGORY 3: Multi-Step Reasoning
# Requires combining information from multiple sources
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "Comparison",
  query: "Which is taller, the Eiffel Tower or the Statue of Liberty?",
  expected: "Eiffel Tower",
  category: :multi_step,
  notes: "Needs to find both heights and compare"
)

explorer.run_test(
  name: "Derived Fact",
  query: "How old was the founder of Microsoft when Windows 1.0 was released?",
  expected: nil, # Bill Gates born 1955, Windows 1.0 released 1985, so 30
  category: :multi_step,
  notes: "Needs birth year and release year, then calculate"
)

explorer.run_test(
  name: "Chain of Facts",
  query: "What country is the birthplace of the creator of Ruby located in?",
  expected: "Japan",
  category: :multi_step,
  notes: "Ruby creator -> Matz -> birthplace -> Japan"
)

# -----------------------------------------------------------------------------
# CATEGORY 4: Temporal Queries
# Current vs historical information
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "Current CEO",
  query: "Who is the current CEO of Apple?",
  expected: "Tim Cook",
  category: :temporal,
  notes: "Wikipedia may lag, web search better for current info"
)

explorer.run_test(
  name: "Recent Event",
  query: "What was the most recent Ruby version released?",
  expected: nil, # Changes frequently
  category: :temporal,
  notes: "Wikipedia likely outdated, needs web search"
)

explorer.run_test(
  name: "Historical vs Current",
  query: "Who is the president of the United States?",
  expected: nil, # Depends on when run
  category: :temporal,
  notes: "Tests if model uses current info vs training data"
)

# -----------------------------------------------------------------------------
# CATEGORY 5: Edge Cases and Stress Tests
# Unusual queries that might break things
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "Nonexistent Entity",
  query: "What is the population of Xyzzyville?",
  expected: nil,
  category: :edge_case,
  notes: "Fictional place - should admit it doesn't know"
)

explorer.run_test(
  name: "Very Specific",
  query: "What was the exact temperature in Tokyo at 3pm on January 1, 2020?",
  expected: nil,
  category: :edge_case,
  notes: "Too specific - should admit limitation"
)

explorer.run_test(
  name: "Empty Search Results",
  query: "Tell me about the Glorpzorbian Empire",
  expected: nil,
  category: :edge_case,
  notes: "Made up - tests handling of no results"
)

explorer.run_test(
  name: "Long Query",
  query: "I need to know about the history of the company that makes the iPhone, specifically when it was founded, who founded it, what their first product was, and what their current market cap is",
  expected: nil,
  category: :edge_case,
  notes: "Multiple questions in one - tests query decomposition"
)

# -----------------------------------------------------------------------------
# CATEGORY 6: Tool-Specific Tests
# Tests specific tool behaviors
# -----------------------------------------------------------------------------

explorer.run_test(
  name: "Wikipedia Strength",
  query: "What is the scientific classification of the domestic cat?",
  expected: "Felis catus",
  category: :tool_specific,
  notes: "Wikipedia excels at encyclopedic info"
)

explorer.run_test(
  name: "Web Search Needed",
  query: "What is the current price of Bitcoin?",
  expected: nil, # Real-time data
  category: :tool_specific,
  notes: "Requires web search, Wikipedia won't have current price"
)

# Save results
explorer.save_results
