# frozen_string_literal: true

# Example: Using PlanOutcome and Agent DSLs for planning
#
# Key insight: Outcomes are FLAT (what we want).
# Hierarchy/orchestration uses the agent DSLs (TeamBuilder, ManagedAgent).
#
# Simple atoms that compose:
# - PlanOutcome.desired("description", criteria: {...})
# - Smolagents.team.agent(...).build
# - Smolagents.code.tools(...).build

require_relative "../lib/smolagents"

# ============================================================
# Pattern 1: Simple Outcomes (what we want to achieve)
# ============================================================
puts "=" * 80
puts "Pattern 1: Flat Outcomes (what we want)"
puts "=" * 80

outcomes = [
  Smolagents::PlanOutcome.desired("Find recent papers",
    criteria: { count: 10..20, recency_days: 1..30 }),

  Smolagents::PlanOutcome.desired("Analyze sentiment",
    criteria: { confidence: 0.8..1.0, categories: 3..5 }),

  Smolagents::PlanOutcome.desired("Generate summary",
    criteria: { length: 500..1000, format: "markdown" })
]

outcomes.each { |o| puts "  #{o}" }
puts

# ============================================================
# Pattern 2: Sequential Execution (single agent)
# ============================================================
puts "=" * 80
puts "Pattern 2: Sequential (single agent, multiple outcomes)"
puts "=" * 80

puts <<~RUBY
  # Define what we want
  outcomes = [
    PlanOutcome.desired("Research topic"),
    PlanOutcome.desired("Analyze findings"),
    PlanOutcome.desired("Write report")
  ]

  # Build agent and run through outcomes
  agent = Smolagents.code
    .model { OpenAI.gpt4 }
    .tools(:web_search, :visit_webpage)
    .build

  actuals = outcomes.map do |desired|
    result = agent.run(desired.description)
    PlanOutcome.from_agent_result(result, desired: desired)
  end
RUBY
puts

# ============================================================
# Pattern 3: Parallel Execution (team of agents)
# ============================================================
puts "=" * 80
puts "Pattern 3: Parallel (team of specialized agents)"
puts "=" * 80

puts <<~RUBY
  # Define parallel outcomes
  outcomes = [
    PlanOutcome.desired("Research topic A"),
    PlanOutcome.desired("Research topic B"),
    PlanOutcome.desired("Research topic C")
  ]

  # Build specialized agents
  researcher = Smolagents.code.model { OpenAI.gpt4 }.tools(:web_search).build

  # Team builder for parallel execution
  team = Smolagents.team
    .agent(researcher.dup, as: "a")
    .agent(researcher.dup, as: "b")
    .agent(researcher.dup, as: "c")
    .build

  # Run in parallel via team
  results = team.run_parallel(outcomes.map(&:description))
RUBY
puts

# ============================================================
# Pattern 4: Sequential Dependencies (via team)
# ============================================================
puts "=" * 80
puts "Pattern 4: Dependencies (ordered team)"
puts "=" * 80

puts <<~RUBY
  # Outcomes with logical sequence
  outcomes = [
    PlanOutcome.desired("Gather data"),
    PlanOutcome.desired("Analyze data"),  # needs data first
    PlanOutcome.desired("Write report")   # needs analysis first
  ]

  # Build specialized agents
  gatherer = Smolagents.code.tools(:web_search).model { ... }.build
  analyzer = Smolagents.code.tools(:calculator).model { ... }.build
  writer   = Smolagents.code.tools(:final_answer).model { ... }.build

  # Team with explicit ordering
  team = Smolagents.team
    .model { coordinator_model }
    .agent(gatherer, as: "gatherer")
    .agent(analyzer, as: "analyzer", after: "gatherer")
    .agent(writer, as: "writer", after: "analyzer")
    .coordinate("Execute in sequence: gather → analyze → write")
    .build
RUBY
puts

# ============================================================
# Pattern 5: Mixed Parallel + Sequential
# ============================================================
puts "=" * 80
puts "Pattern 5: Mixed (some parallel, some sequential)"
puts "=" * 80

puts <<~RUBY
  # Pattern: A → [B,C,D parallel] → E
  team = Smolagents.team
    .model { coordinator_model }
    .agent(setup_agent, as: "setup")
    .agent(worker_a, as: "a", after: "setup")
    .agent(worker_b, as: "b", after: "setup")
    .agent(worker_c, as: "c", after: "setup")
    .agent(finalizer, as: "final", after: ["a", "b", "c"])
    .coordinate("Setup → parallel workers → finalize")
    .build
RUBY
puts

# ============================================================
# Pattern 6: Outcome Verification
# ============================================================
puts "=" * 80
puts "Pattern 6: Outcome Verification (did we achieve what we wanted?)"
puts "=" * 80

# Create desired with criteria
desired = Smolagents::PlanOutcome.desired("Find research papers",
  criteria: {
    count: 10..20,
    recency_days: 1..30,
    quality: ->(v) { v && v > 0.7 }
  })

# Simulate actual result
actual = Smolagents::PlanOutcome.actual("Find research papers",
  state: :success,
  value: { papers: Array.new(15) },
  duration: 2.5,
  count: 15,
  recency_days: 7,
  quality: 0.85)

puts "Desired: #{desired}"
puts "Actual:  #{actual}"
puts
puts "Satisfies criteria? #{actual.satisfies?(desired)}"

if actual.satisfies?(desired)
  puts "✓ All criteria met"
else
  puts "✗ Divergence:"
  actual.divergence(desired).each do |key, diff|
    puts "  #{key}: expected #{diff[:expected]}, got #{diff[:actual]}"
  end
end
puts

# ============================================================
# Key Takeaways
# ============================================================
puts "=" * 80
puts "Key Takeaways"
puts "=" * 80
puts <<~TEXT
  1. PlanOutcome is FLAT - just what we want to achieve
  2. Hierarchy/orchestration uses TeamBuilder DSL
  3. Sequential = single agent or team with after: dependencies
  4. Parallel = team with multiple agents at same level
  5. Verification = actual.satisfies?(desired)

  Composable atoms:
    Smolagents.code           → single code agent
    Smolagents.tool_calling   → single tool-calling agent
    Smolagents.team           → coordinated multi-agent
    PlanOutcome.desired(...)  → what we want
    PlanOutcome.actual(...)   → what we got
TEXT
