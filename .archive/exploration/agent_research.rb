#!/usr/bin/env ruby
# Agent Research Script
# =====================
# Use our agent with ArXiv and Wikipedia to research agent architectures.
# Meta: using the tool we built to research how to build better tools!

require "bundler/setup"
require "smolagents"

RESEARCH_INSTRUCTIONS = <<~INST.freeze
  You are a research assistant helping to understand agent architectures.

  SEARCH STRATEGIES:
  - Use arxiv for academic papers on techniques
  - Use wikipedia for overviews and definitions
  - Search for specific technique names (ReAct, Chain-of-Thought, etc.)

  When summarizing papers:
  - Focus on key techniques and findings
  - Note what information goes in prompts vs tools vs orchestration
  - Identify patterns that help agents succeed
INST

def research_query(gemma, query, context = nil)
  puts "\n#{"=" * 70}"
  puts "RESEARCH QUERY: #{query}"
  puts "=" * 70

  agent = Smolagents.agent
                    .model { gemma }
                    .tools(:arxiv, :wikipedia, :final_answer)
                    .instructions(RESEARCH_INSTRUCTIONS)
                    .max_steps(6)
                    .on(:tool_call) { |e| puts "  → #{e.tool_name}(#{e.args.to_s[0..60]}...)" }
                    .build

  full_query = context ? "#{context}\n\nNow: #{query}" : query
  result = agent.run(full_query)

  puts "\nFINDINGS:"
  puts result.output
  puts "-" * 70

  result.output
end

# Initialize model
gemma = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")

# Research topics
topics = [
  {
    query: "What is ReAct in language models? What are the key components of the ReAct framework?",
    context: nil
  },
  {
    query: "What techniques help language model agents handle tool errors and failures?",
    context: "We're building an agent framework where tools can fail (rate limits, timeouts, no results)"
  },
  {
    query: "What is chain-of-thought prompting and how does it help agents?",
    context: nil
  },
  {
    query: "How should agent prompts be structured? What goes in system prompt vs tool descriptions?",
    context: "We need to decide what information to put in: system prompt, tool descriptions, or observation feedback"
  },
  {
    query: "What techniques help agents understand they are operating over multiple steps?",
    context: "Our agent sometimes forgets the original question or gives up too early"
  }
]

findings = {}

topics.each_with_index do |topic, idx|
  puts "\n\n#{"#" * 70}"
  puts "TOPIC #{idx + 1}/#{topics.size}"
  puts "#" * 70

  findings[topic[:query]] = research_query(gemma, topic[:query], topic[:context])

  # Brief pause between queries
  sleep 1
end

# Save findings
File.write(
  "exploration/results/research_findings_#{Time.now.strftime("%Y%m%d_%H%M%S")}.md",
  "# Agent Architecture Research Findings\n\n" +
  findings.map { |q, a| "## #{q}\n\n#{a}\n" }.join("\n---\n\n")
)

puts "\n\n#{"=" * 70}"
puts "RESEARCH COMPLETE"
puts "=" * 70
puts "Findings saved to exploration/results/"
