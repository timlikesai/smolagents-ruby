#!/usr/bin/env ruby
# frozen_string_literal: true

# Multi-Agent Team Example
#
# A complete example showing how to build a team of specialized agents
# that work together on complex tasks:
#
# - Researcher: Finds information from the web
# - Analyst: Processes and analyzes data
# - Writer: Creates polished final output
# - Coordinator: Orchestrates the team
#
# Usage:
#   OPENAI_API_KEY=sk-... ruby examples/multi_agent_team.rb "topic to research"

require "smolagents"

# =============================================================================
# Configuration
# =============================================================================

MODEL_ID = ENV.fetch("MODEL_ID", "gpt-4")
API_KEY = ENV.fetch("OPENAI_API_KEY") { raise "Set OPENAI_API_KEY environment variable" }

# =============================================================================
# Create the Model
# =============================================================================

# Use local model or configure with your API key
model = Smolagents::OpenAIModel.lm_studio(MODEL_ID)
# Or for OpenAI API: Smolagents::OpenAIModel.new(model_id: MODEL_ID, api_key: API_KEY)

# =============================================================================
# Build Specialized Agents
# =============================================================================

# The Researcher: Finds information from the web
researcher = Smolagents.agent
  .with(:researcher)
  .model { model }
  .tools(:duckduckgo_search, :visit_webpage)
  .max_steps(8)
  .instructions(<<~INSTRUCTIONS)
    You are a research specialist. Your job is to find accurate information.

    When given a research task:
    1. Search for relevant sources using duckduckgo_search
    2. Visit the most authoritative sources using visit_webpage
    3. Extract key facts and data points
    4. Always note where information came from

    Be thorough but efficient. Focus on authoritative sources.
  INSTRUCTIONS
  .build

# The Analyst: Processes data and draws conclusions
analyst = Smolagents.agent
  .with(:code)
  .model { model }
  .tools(:data)
  .max_steps(6)
  .instructions(<<~INSTRUCTIONS)
    You are a data analyst. Your job is to process information and find insights.

    When given data to analyze:
    1. Organize the information systematically
    2. Look for patterns and trends
    3. Calculate relevant statistics
    4. Draw logical conclusions

    Be precise and back up claims with data.
  INSTRUCTIONS
  .build

# The Writer: Creates polished output
writer = Smolagents.agent
  .with(:code)
  .model { model }
  .tools(:data)
  .max_steps(4)
  .instructions(<<~INSTRUCTIONS)
    You are a technical writer. Your job is to create clear, polished content.

    When given raw information:
    1. Organize it into a logical structure
    2. Write clear, concise prose
    3. Add appropriate headings and formatting
    4. Ensure the final output is professional

    Focus on clarity and readability.
  INSTRUCTIONS
  .build

# =============================================================================
# Build the Coordinated Team
# =============================================================================

team = Smolagents.team
  .model { model }
  .agent(researcher, as: "researcher")
  .agent(analyst, as: "analyst")
  .agent(writer, as: "writer")
  .coordinate(<<~COORDINATION)
    You are a project coordinator managing a team of specialists.

    Your team members:
    - researcher: Expert at finding information from the web
    - analyst: Expert at processing data and finding insights
    - writer: Expert at creating polished, readable content

    When given a task:
    1. First, delegate research to the researcher
    2. Then, have the analyst process the findings
    3. Finally, have the writer create the final output

    Always use the most appropriate team member for each subtask.
    Provide clear, specific instructions to each team member.
  COORDINATION
  .coordinator(:code)  # Use code agent as coordinator
  .max_steps(15)
  .planning(interval: 5)
  .on(:before_step) do |step_number:|
    puts "\n--- Coordinator Step #{step_number} ---"
  end
  .on(:after_step) do |step:, monitor:|
    if step.tool_calls&.any?
      step.tool_calls.each do |tc|
        agent_name = tc.name
        puts "  Delegated to: #{agent_name}"
      end
    end
    puts "  Duration: #{monitor.duration.round(2)}s"
  end
  .build

# =============================================================================
# Run the Team
# =============================================================================

topic = ARGV[0] || "Compare the performance characteristics of Ruby, Python, and JavaScript for web backend development"

puts "=" * 70
puts "MULTI-AGENT TEAM"
puts "=" * 70
puts "\nTopic: #{topic}"
puts "Model: #{MODEL_ID}"
puts "\nTeam members:"
puts "  - researcher: web search and content extraction"
puts "  - analyst: data processing and insights"
puts "  - writer: content creation and formatting"
puts "\nStarting collaboration...\n"

begin
  result = team.run(topic)

  puts "\n" + "=" * 70
  puts "FINAL OUTPUT"
  puts "=" * 70
  puts "\n#{result.output}"

  puts "\n" + "-" * 70
  puts "Completed in #{result.steps.count} steps"
  puts "Status: #{result.state}"

rescue Smolagents::AgentMaxStepsError
  puts "\nReached maximum steps. Partial results may be available."
rescue Smolagents::AgentError => e
  puts "\nTeam error: #{e.message}"
  exit 1
end

# =============================================================================
# Alternative: Simpler Two-Agent Setup
# =============================================================================
#
# For simpler tasks, you might just need two agents:

# simple_team = Smolagents.team
#   .model { model }
#   .agent(researcher, as: "researcher")
#   .agent(writer, as: "writer")
#   .coordinate("Research the topic, then write a summary")
#   .build

# =============================================================================
# Notes for Improvement
# =============================================================================
#
# TODO: Consider adding these features:
#
# 1. Agent communication DSL
#    team.workflow do
#      step(:researcher) { |input| search(input) }
#      step(:analyst) { |research| analyze(research) }
#      step(:writer) { |analysis| format(analysis) }
#    end
#
# 2. Parallel execution
#    team.parallel(:researcher, :analyst).then(:writer)
#
# 3. Shared context/memory between agents
#    team.shared_memory(key: "research_findings")
#
# 4. Agent specialization presets
#    Smolagents.preset(:researcher)
#    Smolagents.preset(:analyst)
#    Smolagents.preset(:writer)
