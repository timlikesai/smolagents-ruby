# frozen_string_literal: true

# PlanOutcome - Fluent Goal Management for Agents
#
# Outcomes are the atoms of task decomposition:
# - DESIRED = what we want to achieve
# - ACTUAL = what happened
# - TEMPLATE = reusable patterns
#
# Fluent DSL, composable, executable.

require_relative "../lib/smolagents"

# ============================================================
# 1. Fluent Criteria DSL
# ============================================================
puts "=" * 80
puts "1. Fluent Criteria DSL"
puts "=" * 80

# Build outcomes with expressive, chainable methods
research_goal = Smolagents::PlanOutcome.desired("Find AI safety research papers")
  .expect_count(10..20)           # 10-20 results
  .expect_quality(0.8)            # quality >= 0.8
  .expect_recent(days: 30)        # within last 30 days
  .expect_sources(5..15)          # from 5-15 different sources
  .expect_format("json")          # structured output

puts research_goal
puts "Criteria: #{research_goal.criteria.keys.join(", ")}"
puts

# Custom criteria with blocks
analysis_goal = Smolagents::PlanOutcome.desired("Analyze sentiment distribution")
  .expect_confidence(0.85)
  .expect(:categories) { |cats| cats.is_a?(Hash) && cats.keys.size >= 3 }
  .expect(:balanced) { |scores| scores.values.max - scores.values.min < 0.3 }

puts analysis_goal
puts

# ============================================================
# 2. Quality Shortcut Methods
# ============================================================
puts "=" * 80
puts "2. Quality Shortcuts (aliases for common patterns)"
puts "=" * 80

puts <<~RUBY
  # All these are equivalent ways to express quality requirements:
  .expect_quality(0.8)      # quality >= 0.8
  .expect_confidence(0.8)   # alias for quality
  .expect_score(0.8)        # alias for quality

  # Count variations:
  .expect_count(10..20)     # range
  .expect_count(10)         # at least 10
  .expect_count(10, 20)     # between 10 and 20
  .expect_items(10)         # alias for count
  .expect_results(10)       # alias for count

  # Time/performance:
  .expect_recent(days: 30)  # recency
  .expect_fresh(days: 7)    # alias for recent
  .expect_fast(seconds: 5)  # performance SLA
  .expect_quick(seconds: 1) # alias for fast

  # Content:
  .expect_format("json")    # output format
  .expect_length(500..1000) # content length
  .expect_sources(10..20)   # reference count
RUBY
puts

# ============================================================
# 3. Templates for Reusable Patterns
# ============================================================
puts "=" * 80
puts "3. Templates (reusable outcome patterns)"
puts "=" * 80

# Define a template with placeholders
research_template = Smolagents::PlanOutcome.template("Research :topic in :domain")
  .expect_sources(10..20)
  .expect_recent(days: 30)
  .expect_quality(0.8)

puts "Template: #{research_template}"

# Instantiate with different variables
ai_safety = research_template.for(topic: "alignment", domain: "AI safety")
ruby_perf = research_template.for(topic: "Ractors", domain: "Ruby concurrency")
llm_agents = research_template.for(topic: "tool use", domain: "LLM agents")

puts "Instance 1: #{ai_safety}"
puts "Instance 2: #{ruby_perf}"
puts "Instance 3: #{llm_agents}"
puts

# ============================================================
# 4. Agent Binding and Execution
# ============================================================
puts "=" * 80
puts "4. Agent Binding (.with_agent, .run!)"
puts "=" * 80

puts <<~RUBY
  # Bind outcome to agent for direct execution
  researcher = Smolagents.code
    .model { OpenAI.gpt4 }
    .tools(:web_search, :visit_webpage)
    .build

  # Execute and get actual outcome
  actual = PlanOutcome.desired("Find Ruby 4.0 features")
    .expect_count(5..10)
    .expect_quality(0.8)
    .with_agent(researcher)
    .run!

  # Check results
  if actual.success?
    puts "Found \#{actual.value}"
  elsif actual.partial?
    puts "Partial: \#{actual.divergence(desired)}"
  else
    puts "Failed: \#{actual.error}"
  end

  # Satisfaction check
  actual.satisfies?(desired)  # => true/false
  actual >= desired           # => same thing, operator style
RUBY
puts

# ============================================================
# 5. Dependencies (lightweight ordering)
# ============================================================
puts "=" * 80
puts "5. Dependencies (.after for ordering)"
puts "=" * 80

gather = Smolagents::PlanOutcome.desired("Gather research data")
  .expect_count(20..50)

analyze = Smolagents::PlanOutcome.desired("Analyze findings")
  .expect_confidence(0.85)
  .after(gather)

visualize = Smolagents::PlanOutcome.desired("Create visualizations")
  .expect_count(3..5)
  .after(gather)

report = Smolagents::PlanOutcome.desired("Write final report")
  .expect_length(1000..2000)
  .after(analyze, visualize)

puts "Dependencies:"
puts "  gather → (no deps)"
puts "  analyze → after(gather)"
puts "  visualize → after(gather)"
puts "  report → after(analyze, visualize)"
puts
puts "Execution order respects dependencies automatically."
puts

# ============================================================
# 6. Composition Operators
# ============================================================
puts "=" * 80
puts "6. Composition (& for AND, | for OR)"
puts "=" * 80

primary = Smolagents::PlanOutcome.desired("Search primary API")
backup = Smolagents::PlanOutcome.desired("Search backup API")
manual = Smolagents::PlanOutcome.desired("Manual data entry")

# Both must succeed
research = Smolagents::PlanOutcome.desired("Research phase")
analysis = Smolagents::PlanOutcome.desired("Analysis phase")
combined = research & analysis
puts "AND: #{combined}"

# First success wins (fallback chain)
resilient = primary | backup | manual
puts "OR:  #{resilient}"

puts <<~RUBY

  # Execute composite outcomes:
  result = combined.run_with(agent)
  result.success?        # => true if ALL succeeded
  result.summary         # => { total: 2, success: 2, ... }

  result = resilient.run_with(agent)
  result.success?        # => true if ANY succeeded
  result.successful_results  # => [first_success]
RUBY
puts

# ============================================================
# 7. Collection Operations
# ============================================================
puts "=" * 80
puts "7. Collection Extensions"
puts "=" * 80

# Create sample outcomes
outcomes = [
  Smolagents::PlanOutcome.actual("Task A", state: :success, duration: 1.2),
  Smolagents::PlanOutcome.actual("Task B", state: :success, duration: 0.8),
  Smolagents::PlanOutcome.actual("Task C", state: :partial, duration: 2.1),
  Smolagents::PlanOutcome.actual("Task D", state: :error, duration: 0.5, error: StandardError.new("oops")),
  Smolagents::PlanOutcome.actual("Task E", state: :success, duration: 1.5)
]
outcomes.extend(Smolagents::Types::PlanOutcome::Collection)

puts "Summary:"
summary = outcomes.summary
summary.each { |k, v| puts "  #{k}: #{v}" }
puts
puts "Successes: #{outcomes.successes.map(&:description).join(", ")}"
puts "Failures:  #{outcomes.failures.map(&:description).join(", ")}"
puts "Success rate: #{(outcomes.success_rate * 100).round(1)}%"
puts "Total duration: #{outcomes.total_duration.round(2)}s"
puts

# ============================================================
# 8. Outcome Verification
# ============================================================
puts "=" * 80
puts "8. Outcome Verification"
puts "=" * 80

desired = Smolagents::PlanOutcome.desired("Find research papers")
  .expect_count(10..20)
  .expect_quality(0.8..1.0)
  .expect_recent(days: 30)

# Simulate actual result that meets criteria
actual_good = Smolagents::PlanOutcome.actual("Find research papers",
  state: :success,
  value: { papers: Array.new(15) },
  duration: 2.5,
  count: 15,
  quality: 0.92,
  recency_days: 7)

# Simulate actual result that misses some criteria
actual_partial = Smolagents::PlanOutcome.actual("Find research papers",
  state: :success,
  value: { papers: Array.new(8) },
  duration: 2.5,
  count: 8,       # Below minimum
  quality: 0.75,  # Below threshold
  recency_days: 7)

puts "Desired: #{desired}"
puts
puts "Actual (good): #{actual_good}"
puts "  Satisfies? #{actual_good.satisfies?(desired)}"
puts "  Using >=:  #{actual_good >= desired}"
puts
puts "Actual (partial): #{actual_partial}"
puts "  Satisfies? #{actual_partial.satisfies?(desired)}"
divergence = actual_partial.divergence(desired)
puts "  Divergence:"
divergence.each do |key, diff|
  puts "    #{key}: expected #{diff[:expected]}, got #{diff[:actual]}"
end
puts

# ============================================================
# 9. Full Workflow Example
# ============================================================
puts "=" * 80
puts "9. Full Workflow Example"
puts "=" * 80

puts <<~RUBY
  # Define outcome template
  research_template = PlanOutcome.template("Research :topic")
    .expect_sources(10..20)
    .expect_quality(0.8)
    .expect_recent(days: 30)

  # Build specialized agents
  researcher = Smolagents.code
    .model { OpenAI.gpt4 }
    .tools(:web_search, :visit_webpage)
    .build

  analyzer = Smolagents.code
    .model { OpenAI.gpt4 }
    .tools(:calculator)
    .build

  # Define workflow with dependencies
  gather = research_template.for(topic: "AI agents")
  analyze = PlanOutcome.desired("Analyze trends")
    .expect_confidence(0.85)
    .after(gather)
  report = PlanOutcome.desired("Write summary")
    .expect_length(500..1000)
    .after(analyze)

  # Execute workflow
  outcomes = [gather, analyze, report]
  outcomes.extend(PlanOutcome::Collection)

  results = outcomes.execute_with(researcher)

  # Check results
  puts results.summary
  puts "Success rate: \#{results.success_rate * 100}%"
RUBY
puts

# ============================================================
# Key Takeaways
# ============================================================
puts "=" * 80
puts "Key Takeaways"
puts "=" * 80
puts <<~TEXT
  PlanOutcome provides fluent goal management:

  1. FLUENT CRITERIA
     .expect_quality(0.8)
     .expect_count(10..20)
     .expect_recent(days: 30)

  2. TEMPLATES
     template = PlanOutcome.template("Research :topic")
     concrete = template.for(topic: "AI Safety")

  3. AGENT BINDING
     actual = desired.with_agent(agent).run!

  4. DEPENDENCIES
     analysis.after(research)
     report.after(analysis, visualization)

  5. COMPOSITION
     combined = outcome_a & outcome_b  # AND
     fallback = primary | backup       # OR

  6. COLLECTIONS
     outcomes.extend(PlanOutcome::Collection)
     outcomes.summary
     outcomes.execute_with(agent)

  These patterns apply across all smolagents DSLs for consistency.
TEXT
