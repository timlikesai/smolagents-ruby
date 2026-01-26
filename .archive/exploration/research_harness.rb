#!/usr/bin/env ruby
# Research Harness
# ================
# A reusable harness for using our agent to research agent architecture patterns.
# Outputs structured findings for synthesis.

require "bundler/setup"
require "smolagents"
require "json"
require "fileutils"

module ResearchHarness
  RESEARCH_INSTRUCTIONS = <<~INST.freeze
    You are a research assistant helping to understand agent architectures and AI patterns.

    SEARCH STRATEGIES:
    - Use arxiv for academic papers on AI agent techniques
    - Use wikipedia for overviews, definitions, and foundational concepts
    - Search for specific technique names and authors when mentioned

    When summarizing findings:
    - Focus on KEY TECHNIQUES and their purpose
    - Note IMPLEMENTATION IMPLICATIONS for agent frameworks
    - Identify PATTERNS that can be applied to Ruby agent systems
    - Cite paper titles and authors when relevant
  INST

  class Session
    attr_reader :model, :results_dir

    def initialize(model_name: "gemma-3n-e4b", results_dir: "exploration/results")
      @model = Smolagents::OpenAIModel.lm_studio(model_name)
      @results_dir = results_dir
      FileUtils.mkdir_p(results_dir)
      @findings = []
    end

    def research(topic:, queries:, context: nil)
      puts "\n#{"=" * 70}"
      puts "RESEARCH TOPIC: #{topic}"
      puts "=" * 70

      topic_findings = { topic:, context:, queries: [], timestamp: Time.now.iso8601 }

      queries.each_with_index do |query, idx|
        puts "\n  Query #{idx + 1}/#{queries.size}: #{query[0..60]}..."
        finding = execute_query(query, context)
        topic_findings[:queries] << finding
        sleep 1 # Rate limit
      end

      @findings << topic_findings
      topic_findings
    end

    def save_findings(filename: nil)
      filename ||= "research_#{Time.now.strftime("%Y%m%d_%H%M%S")}.json"
      path = File.join(results_dir, filename)
      File.write(path, JSON.pretty_generate(@findings))
      puts "\nFindings saved to: #{path}"
      path
    end

    def synthesize
      puts "\n#{"=" * 70}"
      puts "SYNTHESIZING FINDINGS"
      puts "=" * 70

      @findings.each do |topic|
        puts "\n## #{topic[:topic]}"
        topic[:queries].each do |q|
          puts "\n### #{q[:query][0..50]}..."
          puts q[:answer] if q[:answer]
          puts "Tools used: #{q[:tools_used].join(", ")}" if q[:tools_used]&.any?
        end
      end
    end

    private

    def execute_query(query, context)
      agent = build_agent
      full_query = context ? "Context: #{context}\n\nQuery: #{query}" : query

      finding = { query:, tools_used: [], answer: nil, error: nil }

      begin
        result = agent.run(full_query)
        finding[:answer] = result.output
        finding[:tools_used] = extract_tools_used(result)
      rescue StandardError => e
        finding[:error] = "#{e.class}: #{e.message}"
        puts "    Error: #{finding[:error]}"
      end

      finding
    end

    def build_agent
      Smolagents.agent
                .model { @model }
                .tools(:arxiv, :wikipedia, :final_answer)
                .instructions(RESEARCH_INSTRUCTIONS)
                .max_steps(8)
                .on(:tool_call) { |e| print "    → #{e.tool_name} " }
                .build
    end

    def extract_tools_used(result)
      return [] unless result.respond_to?(:steps)

      result.steps
            .flat_map { |s| s.tool_calls || [] }
            .map(&:name)
            .uniq
    end
  end

  # Predefined research agendas
  module Agendas
    ORCHESTRATION_PATTERNS = {
      topic: "Agent Orchestration Patterns",
      context: "We're building a Ruby agent framework that needs sophisticated orchestration. " \
               "Agents can call tools, manage sub-agents, and need internal state management.",
      queries: [
        "What are the latest techniques for multi-agent orchestration in LLM systems?",
        "How do modern agent frameworks handle internal state and goal tracking?",
        "What is hierarchical task planning in AI agents and how is it implemented?",
        "What patterns exist for agent self-reflection and internal reasoning loops?",
        "How do frameworks handle retry-then-verify patterns in agent tool execution?"
      ]
    }.freeze

    INTERNAL_MODE_STATES = {
      topic: "Internal Mode States and Control Flow",
      context: "Our agent framework uses events and fibers for control flow. " \
               "We need patterns for internal decision-making before surfacing output.",
      queries: [
        "What is inner monologue or chain-of-thought in AI agents?",
        "How do ReAct agents balance reasoning and action phases?",
        "What techniques exist for agent metacognition and self-monitoring?",
        "How do agents handle uncertainty and when to ask for clarification vs proceed?"
      ]
    }.freeze

    GOAL_TRACKING = {
      topic: "Goal Tracking and Planning",
      context: "Agents need to track progress toward goals, decompose complex tasks, " \
               "and know when sub-goals are complete.",
      queries: [
        "What is task decomposition in AI agent planning?",
        "How do agents track and update goals during execution?",
        "What is plan-then-execute vs interleaved planning in agents?",
        "How do modern agents handle goal conflicts and priority changes?"
      ]
    }.freeze

    SUB_AGENT_PATTERNS = {
      topic: "Sub-Agent and Team Patterns",
      context: "Our framework supports managed sub-agents. We need patterns for " \
               "how parent agents delegate, coordinate, and aggregate sub-agent results.",
      queries: [
        "What patterns exist for multi-agent collaboration and delegation?",
        "How do agent hierarchies handle information flow between levels?",
        "What is the debate pattern in multi-agent systems?",
        "How do frameworks handle sub-agent failure and recovery?"
      ]
    }.freeze

    def self.all
      [ORCHESTRATION_PATTERNS, INTERNAL_MODE_STATES, GOAL_TRACKING, SUB_AGENT_PATTERNS]
    end
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  session = ResearchHarness::Session.new

  puts "Research Harness - Agent Architecture Exploration"
  puts "=" * 50

  # Run all agendas
  ResearchHarness::Agendas.all.each do |agenda|
    session.research(
      topic: agenda[:topic],
      queries: agenda[:queries],
      context: agenda[:context]
    )
  end

  # Save and synthesize
  session.save_findings
  session.synthesize
end
