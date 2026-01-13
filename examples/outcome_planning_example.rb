# frozen_string_literal: true

# Example: Using Outcome DSL for hierarchical agent planning
#
# This shows how the Outcome DSL enables agents to:
# 1. Define complex multi-step plans declaratively
# 2. Spawn sub-agents with clear success criteria
# 3. Track actual vs desired outcomes
# 4. Automatically detect and handle divergence

require_relative "../lib/smolagents"

# Example 1: Simple linear plan
puts "=" * 80
puts "Example 1: Simple Linear Plan"
puts "=" * 80

tree = Smolagents::PlanOutcome.plan("Research AI safety trends") do
  step "Find recent papers" do
    expect results: 10..20, recency_days: 1..30
  end

  step "Analyze sentiment" do
    expect confidence: 0.8..1.0, categories: 3..5
  end

  step "Generate summary" do
    expect length: 500..1000, format: "markdown"
  end
end

puts tree.trace
puts

# Example 2: With dependencies and sub-agents
puts "=" * 80
puts "Example 2: Complex Plan with Dependencies"
puts "=" * 80

market_research = Smolagents::PlanOutcome.plan("Complete market research report") do
  step "Define research scope" do
    expect topics: 3..5, time_range: "6 months"
  end

  step "Gather competitive data", depends_on: "Define research scope" do
    spawn_agent :web_searcher, model: "gpt-4-turbo"
    expect sources: 10..15, source_quality: ->(q) { q > 0.7 }
  end

  step "Analyze competitors", depends_on: "Gather competitive data" do
    use_agent :analyzer
    expect insights: 5..10, depth_score: 7..10
  end

  parallel do
    step "Create visualizations" do
      use_agent :data_visualizer
      expect charts: 3..5, format: "png", resolution: /\d{3,4}x\d{3,4}/
    end

    step "Write executive summary" do
      use_agent :summarizer, model: "claude-3.5-sonnet"
      expect length: 500..1000, readability_score: 8..10
    end
  end

  step "Final review", depends_on: ["Analyze competitors", "Write executive summary"] do
    expect completeness: 0.9..1.0, accuracy: 0.95..1.0
  end
end

puts market_research.trace
puts "\nExecution order: #{market_research.topological_sort.join(" → ")}"
puts

# Example 3: Nested decomposition (hierarchical breakdown)
puts "=" * 80
puts "Example 3: Nested Hierarchical Planning"
puts "=" * 80

web_scraper = Smolagents::PlanOutcome.plan("Build production web scraper") do
  step "Design architecture" do
    step "Choose libraries" do
      expect libraries: ["nokogiri", "selenium"]
    end

    step "Define data models" do
      expect models: 3..5, validation: true
    end

    step "Plan error handling" do
      expect retry_strategy: "exponential_backoff"
    end
  end

  step "Implement core functionality", depends_on: "Design architecture" do
    step "Core scraping logic" do
      use_agent :code_generator
      expect lines_of_code: 100..300, test_coverage: 0.8..1.0
    end

    step "Data validation layer" do
      use_agent :code_generator
      expect validators: 5..10
    end

    step "Storage integration" do
      expect database: "postgresql", migrations: 3..5
    end
  end

  step "Testing", depends_on: "Implement core functionality" do
    parallel do
      step "Unit tests" do
        expect coverage: 0.9..1.0
      end

      step "Integration tests" do
        expect scenarios: 10..15
      end

      step "Load testing" do
        expect requests_per_second: 100..500
      end
    end
  end
end

puts web_scraper.trace
puts

# Example 4: Execution with actual vs desired tracking
puts "=" * 80
puts "Example 4: Executing Plan and Tracking Outcomes"
puts "=" * 80

simple_plan = Smolagents::PlanOutcome.plan("Analyze customer feedback") do
  step "Collect feedback" do
    expect count: 100..200, sources: ["email", "survey", "social"]
  end

  step "Categorize sentiment", depends_on: "Collect feedback" do
    expect categories: { positive: 40..60, neutral: 20..40, negative: 10..30 }
  end

  step "Generate insights", depends_on: "Categorize sentiment" do
    expect insights: 5..10, actionable: true
  end
end

puts "Desired plan:"
puts simple_plan.trace
puts

# Simulate execution
results = simple_plan.execute do |desired_step, previous_results|
  puts "Executing: #{desired_step.description}"

  # Simulate agent work
  case desired_step.description
  when "Collect feedback"
    { count: 150, sources: ["email", "survey", "social"], quality: 0.85 }
  when "Categorize sentiment"
    { categories: { positive: 55, neutral: 30, negative: 15 }, confidence: 0.9 }
  when "Generate insights"
    { insights: 7, actionable: true, quality: 0.88 }
  end
end

puts "\nActual results:"
results.each do |step_name, actual_outcome|
  desired = simple_plan.steps[step_name]

  puts "\n#{actual_outcome.description}:"
  puts "  Status: #{actual_outcome.state}"
  puts "  Duration: #{actual_outcome.duration.round(3)}s"

  if actual_outcome.satisfies?(desired)
    puts "  ✓ Meets all criteria"
  else
    puts "  ✗ Divergence detected:"
    actual_outcome.divergence(desired).each do |key, diff|
      puts "    - #{key}: expected #{diff[:expected]}, got #{diff[:actual]}"
    end
  end
end

puts

# Example 5: LLM-generated plan (what an agent might write)
puts "=" * 80
puts "Example 5: LLM-Friendly DSL (what agents write)"
puts "=" * 80

# This is the kind of simple, readable code an LLM can easily generate
agent_generated_plan = Smolagents::PlanOutcome.plan("Build customer dashboard") do
  step "Design UI mockups" do
    use_agent :designer
    expect mockups: 5..8, format: "figma"
  end

  step "Implement frontend", depends_on: "Design UI mockups" do
    use_agent :frontend_developer
    expect components: 10..15, framework: "react"
  end

  step "Create API endpoints", depends_on: "Design UI mockups" do
    use_agent :backend_developer
    expect endpoints: 5..10, authentication: true
  end

  step "Integration", depends_on: ["Implement frontend", "Create API endpoints"] do
    parallel do
      step "Connect frontend to API" do
        expect integration_tests: 10..20
      end

      step "Add error handling" do
        expect coverage: 0.9..1.0
      end
    end
  end

  step "Deploy to staging", depends_on: "Integration" do
    expect environment: "staging", health_check: true
  end
end

puts agent_generated_plan.trace
puts "\nPlan structure:"
puts JSON.pretty_generate(agent_generated_plan.to_h)
