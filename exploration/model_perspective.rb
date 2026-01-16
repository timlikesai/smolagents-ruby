#!/usr/bin/env ruby
# Model Perspective Analysis
# ==========================
# See exactly what the model receives to understand failure modes.

require "bundler/setup"
require "smolagents"

# Capture what the model sees
class ModelInspector
  def initialize
    @captured_prompts = []
    @captured_messages = []
  end

  def inspect_agent
    # Build agent and capture its system prompt
    agent = Smolagents.agent
                      .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
                      .tools(:search)
                      .build

    puts "=" * 80
    puts "SYSTEM PROMPT (what model sees at start)"
    puts "=" * 80
    puts agent.system_prompt
    puts "\n#{"=" * 80}"

    # Now let's look at tool definitions
    puts "\nTOOL DEFINITIONS:"
    agent.instance_variable_get(:@tools).each do |name, tool|
      puts "\n--- #{name} ---"
      puts "Description: #{tool.class.description[0..200]}"
      puts "Inputs: #{tool.class.inputs.inspect}"
    end
  end

  def show_observation_format
    # Show how tool results become observations
    puts "\n#{"=" * 80}"
    puts "OBSERVATION FORMAT EXAMPLES"
    puts "=" * 80

    wiki = Smolagents::WikipediaSearchTool.new(max_results: 1)

    # Example search
    puts "\n--- Wikipedia result for 'Ruby programming' ---"
    result = wiki.call(query: "Ruby programming")
    puts "Result type: #{result.class}"
    puts "Result preview:"
    puts result.to_s[0..500]
    puts "..."
    puts "\nTotal length: #{result.to_s.length} chars"
  end
end

inspector = ModelInspector.new
inspector.inspect_agent
inspector.show_observation_format

# Now let's analyze the prompt structure
puts "\n#{"=" * 80}"
puts "PROMPT ANALYSIS"
puts "=" * 80

puts <<~ANALYSIS

  KEY OBSERVATIONS:

  1. SYSTEM PROMPT STRUCTURE
     - Contains tool definitions with JSON schema
     - Has instructions for how to use tools
     - May or may not have guidance on answer formatting

  2. TOOL RESULT FORMAT
     - Wikipedia returns markdown with ## headers
     - Results can be 2000+ chars
     - Multiple results separated by ---

  3. POTENTIAL ISSUES
     - Long results may overwhelm context
     - No explicit "answer the EXACT question" instruction
     - No verification step in prompt

  IMPROVEMENT IDEAS:

  1. Add explicit answer-matching instruction:
     "Before giving final_answer, verify it directly answers the original question"

  2. Shorten tool results:
     - Truncate at 500 chars per result
     - Extract key facts only

  3. Add question decomposition:
     "Break down complex questions into sub-questions"

  4. Add entity matching:
     "Ensure entities in answer match entities in question"

ANALYSIS
