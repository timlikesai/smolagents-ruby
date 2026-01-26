#!/usr/bin/env ruby
# Prompt Improvement Experiments
# ==============================
# Test different prompt variations to address identified failure modes.

require "bundler/setup"
require "smolagents"

# Custom prompt injection via custom_instructions
class PromptExperiment
  def initialize(model_name: "gemma-3n-e4b")
    @model = Smolagents::OpenAIModel.lm_studio(model_name)
  end

  def test_prompt(name:, instructions:, queries:)
    puts "\n#{"=" * 80}"
    puts "EXPERIMENT: #{name}"
    puts "=" * 80
    puts "CUSTOM INSTRUCTIONS:"
    puts instructions
    puts "-" * 80

    queries.each do |q|
      test_query(instructions:, **q)
    end
  end

  def test_query(query:, expected:, instructions:, failure_mode:)
    puts "\nQuery: #{query}"
    puts "Expected: #{expected}"
    puts "Failure mode being addressed: #{failure_mode}"

    agent = Smolagents.agent
                      .model { @model }
                      .tools(:search)
                      .custom_instructions(instructions)
                      .max_steps(6)
                      .build

    result = agent.run(query)

    correct = expected && result.output&.downcase&.include?(expected.downcase)
    status = correct ? "✓ PASS" : "✗ FAIL"

    puts "Result: #{result.output}"
    puts "Status: #{status}"
    puts
  end
end

exp = PromptExperiment.new

# =============================================================================
# EXPERIMENT 1: Answer Verification
# Address: Search result confusion (Statue of Unity vs Liberty)
# =============================================================================

exp.test_prompt(
  name: "Answer Verification Rule",
  instructions: <<~INST,
    IMPORTANT: Before calling final_answer, verify your answer:
    1. Re-read the original question
    2. Check that entities in your answer match entities in the question
    3. If asked about X, your answer must be about X, not similar-sounding Y
  INST
  queries: [
    {
      query: "Which is taller, the Eiffel Tower or the Statue of Liberty?",
      expected: "Eiffel Tower",
      failure_mode: "search_confusion"
    }
  ]
)

# =============================================================================
# EXPERIMENT 2: Semantic Precision
# Address: "Who plays" vs "character name" confusion
# =============================================================================

exp.test_prompt(
  name: "Semantic Precision Rule",
  instructions: <<~INST,
    IMPORTANT: Parse the question carefully:
    - "Who plays X" = the ACTOR's name (person in real life)
    - "Who is X" = the CHARACTER (in the story)
    - "What country" = the country NAME (e.g., "Japan")
    - "What nationality" = the adjective (e.g., "Japanese")
    Answer exactly what was asked.
  INST
  queries: [
    {
      query: "Who plays the main character in The Office (US version)?",
      expected: "Steve Carell",
      failure_mode: "semantic_confusion"
    },
    {
      query: "What country is the birthplace of the creator of Ruby located in?",
      expected: "Japan",
      failure_mode: "incomplete_answer"
    }
  ]
)

# =============================================================================
# EXPERIMENT 3: Combined Improvements
# All improvements together
# =============================================================================

exp.test_prompt(
  name: "Combined Improvements",
  instructions: <<~INST,
    ANSWER QUALITY RULES:
    1. Parse question precisely - "who plays X" means the actor, "who is X" means the character
    2. Match entities exactly - if asked about Statue of Liberty, don't answer about Statue of Unity
    3. Answer the exact form asked - "what country" needs a country name, not a nationality adjective
    4. Before final_answer, verify your answer directly addresses what was asked
  INST
  queries: [
    {
      query: "What is the street address of the New York Times headquarters?",
      expected: "620 Eighth Avenue",
      failure_mode: "fact_retrieval"
    },
    {
      query: "Who plays the main character in The Office (US version)?",
      expected: "Steve Carell",
      failure_mode: "semantic_confusion"
    },
    {
      query: "What country is the birthplace of the creator of Ruby located in?",
      expected: "Japan",
      failure_mode: "incomplete_answer"
    },
    {
      query: "Which is taller, the Eiffel Tower or the Statue of Liberty?",
      expected: "Eiffel Tower",
      failure_mode: "search_confusion"
    }
  ]
)

# =============================================================================
# EXPERIMENT 4: Minimal Addition
# Test the smallest effective change
# =============================================================================

exp.test_prompt(
  name: "Minimal - Just Verification",
  instructions: "Before final_answer, verify your answer matches the exact question asked.",
  queries: [
    {
      query: "Who plays the main character in The Office (US version)?",
      expected: "Steve Carell",
      failure_mode: "semantic_confusion"
    }
  ]
)

puts "\n#{"=" * 80}"
puts "EXPERIMENT SUMMARY"
puts "=" * 80
puts <<~SUMMARY

  The experiments above test different prompt additions to address:

  1. SEARCH CONFUSION: Model confuses similar entities (Liberty vs Unity)
     → Add verification rule to check entity match

  2. SEMANTIC CONFUSION: Model misparses "who plays" as character vs actor
     → Add semantic parsing guidance

  3. INCOMPLETE ANSWERS: Model answers "Japanese" instead of "Japan"
     → Add answer form precision rule

  4. COMBINED: All improvements together

  Results show which improvements help and can be incorporated into
  the default agent prompt in utilities/prompts.rb

SUMMARY
