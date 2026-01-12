#!/usr/bin/env ruby
# frozen_string_literal: true

# Research Assistant Example
#
# A complete, practical example of building a research agent that can:
# - Search the web for information
# - Visit and extract content from web pages
# - Synthesize findings into a coherent summary
# - Track sources for citations
#
# Usage:
#   OPENAI_API_KEY=sk-... ruby examples/research_assistant.rb "your research topic"

require "smolagents"

# =============================================================================
# Configuration
# =============================================================================

MODEL_ID = ENV.fetch("MODEL_ID", "gpt-4")
API_KEY = ENV.fetch("OPENAI_API_KEY") { raise "Set OPENAI_API_KEY environment variable" }
MAX_STEPS = 15
PLANNING_INTERVAL = 5

# =============================================================================
# Custom Tool: Source Tracker
# =============================================================================
#
# Tracks URLs visited during research for citation purposes.

class SourceTrackerTool < Smolagents::Tool
  self.tool_name = "track_source"
  self.description = "Record a source URL with a brief description for citation"
  self.inputs = {
    url: { type: "string", description: "URL of the source" },
    title: { type: "string", description: "Title or brief description" },
    relevance: { type: "string", description: "How this source is relevant to the research" }
  }
  self.output_type = "string"

  def initialize
    @sources = []
    super()
  end

  attr_reader :sources

  def execute(url:, title:, relevance:)
    @sources << { url: url, title: title, relevance: relevance, added_at: Time.now }
    "Source tracked: #{title} (#{@sources.count} total sources)"
  end

  def format_citations
    return "No sources tracked." if @sources.empty?

    @sources.map.with_index(1) do |source, i|
      "[#{i}] #{source[:title]}\n    #{source[:url]}\n    Relevance: #{source[:relevance]}"
    end.join("\n\n")
  end
end

# =============================================================================
# Build the Research Agent
# =============================================================================

source_tracker = SourceTrackerTool.new

model = Smolagents::OpenAIModel.new(
  model_id: MODEL_ID,
  api_key: API_KEY
)

agent = Smolagents.agent(:code)
  .model { model }
  .tools(
    :duckduckgo_search,  # Search the web
    :visit_webpage,      # Extract page content
    source_tracker,      # Track sources
    :final_answer        # Return results
  )
  .max_steps(MAX_STEPS)
  .planning(interval: PLANNING_INTERVAL)
  .instructions(<<~INSTRUCTIONS)
    You are a thorough research assistant. When given a research topic:

    1. SEARCH: Use duckduckgo_search to find relevant sources
    2. INVESTIGATE: Use visit_webpage on the most promising URLs
    3. TRACK: Use track_source for every URL you reference
    4. SYNTHESIZE: Combine findings into a clear, well-organized summary

    Always:
    - Search for multiple perspectives on the topic
    - Visit at least 2-3 sources before drawing conclusions
    - Track every source you use for proper citation
    - Organize your findings with clear headings
    - Note any conflicting information you find
  INSTRUCTIONS
  .on(:before_step) do |step_number:|
    puts "\n--- Step #{step_number} ---"
  end
  .on(:after_step) do |step:, monitor:|
    if step.tool_calls&.any?
      step.tool_calls.each do |tc|
        puts "  Called: #{tc.name}"
      end
    end
    puts "  Duration: #{monitor.duration.round(2)}s"
  end
  .on(:on_tokens_tracked) do |usage:|
    puts "  Tokens: #{usage.input_tokens} in, #{usage.output_tokens} out"
  end
  .build

# =============================================================================
# Run the Research
# =============================================================================

topic = ARGV[0] || "What are the key differences between Ruby 3.2 and Ruby 3.3?"

puts "=" * 70
puts "RESEARCH ASSISTANT"
puts "=" * 70
puts "\nTopic: #{topic}"
puts "Model: #{MODEL_ID}"
puts "Max steps: #{MAX_STEPS}"
puts "\nStarting research...\n"

begin
  result = agent.run(topic)

  puts "\n" + "=" * 70
  puts "RESEARCH FINDINGS"
  puts "=" * 70
  puts "\n#{result.output}"

  puts "\n" + "=" * 70
  puts "SOURCES"
  puts "=" * 70
  puts "\n#{source_tracker.format_citations}"

  puts "\n" + "=" * 70
  puts "SUMMARY"
  puts "=" * 70
  puts "Status: #{result.state}"
  puts "Steps taken: #{result.steps.count}"
  puts "Sources tracked: #{source_tracker.sources.count}"

  if result.token_usage
    puts "Total tokens: #{result.token_usage.total_tokens}"
  end

rescue Smolagents::AgentMaxStepsError
  puts "\nReached maximum steps. Partial results may be available."
  puts "Sources collected: #{source_tracker.sources.count}"
rescue Smolagents::AgentError => e
  puts "\nAgent error: #{e.message}"
  exit 1
rescue StandardError => e
  puts "\nUnexpected error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

# =============================================================================
# Notes for Improvement
# =============================================================================
#
# TODO: Consider adding these features to the library:
#
# 1. Built-in source tracking concern for agents
#    - agent.sources would return all URLs visited
#    - Automatic deduplication
#
# 2. Result formatting helpers
#    - result.as_markdown for formatted output
#    - result.with_citations for appending sources
#
# 3. Agent.research convenience factory
#    - Pre-configured for research tasks
#    - Smolagents.research_agent(topic: "...")
