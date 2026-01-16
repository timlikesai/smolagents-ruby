#!/usr/bin/env ruby
# Detailed Agent Trace
# ====================
# Traces exactly what the model sees at each step to understand failure modes.

require "bundler/setup"
require "smolagents"

class DetailedTracer
  def initialize(model_name: "gemma-3n-e4b")
    @model = Smolagents::OpenAIModel.lm_studio(model_name)
  end

  def trace(query, max_steps: 8)
    puts "=" * 80
    puts "QUERY: #{query}"
    puts "=" * 80

    step_num = 0

    agent = Smolagents.agent
                      .model { @model }
                      .tools(:search)
                      .max_steps(max_steps)
                      .on(:tool_call) do |e|
                        puts "\n--- TOOL CALL ---"
                        puts "Tool: #{e.tool_name}"
                        puts "Args: #{e.args.inspect}"
    end
      .on(:tool_complete) do |e|
        puts "\n--- TOOL RESULT (truncated) ---"
        result_preview = e.result.to_s
        if result_preview.length > 500
          puts result_preview[0..500] + "\n... [#{result_preview.length - 500} more chars]"
        else
          puts result_preview
        end
      end
      .on(:step_complete) do |e|
        step_num += 1
        puts "\n#{"*" * 80}"
        puts "STEP #{step_num} COMPLETE"
        puts "Outcome: #{e.outcome}"
        puts "Observations: #{e.observations&.slice(0, 200)}..." if e.observations
        puts "*" * 80
      end
      .on(:error) do |e|
        puts "\n!!! ERROR !!!"
        puts "Type: #{e.error_class}"
        puts "Message: #{e.error_message}"
        puts "Recoverable: #{e.recoverable?}"
      end
      .build

    puts "\n>>> STARTING AGENT EXECUTION <<<"
    result = agent.run(query)

    puts "\n#{"=" * 80}"
    puts "FINAL RESULT"
    puts "=" * 80
    puts "Steps taken: #{step_num}"
    puts "Output: #{result.output || "(no output)"}"
    puts "State: #{result.state}" if result.respond_to?(:state)

    result
  end
end

# Run specific failure cases for analysis
tracer = DetailedTracer.new

# Test 1: The failing "Chain of Facts" query
puts "\n\n#{"=" * 80}"
puts "TEST 1: Chain of Facts (previously failed with no output)"
puts "=" * 80
tracer.trace("What country is the birthplace of the creator of Ruby located in?")

# Test 2: The hallucination case
puts "\n\n#{"=" * 80}"
puts "TEST 2: The Office (previously gave wrong answer 'Ryan Howard')"
puts "=" * 80
tracer.trace("Who plays the main character in The Office?")

# Test 3: Multi-step that worked (for comparison)
puts "\n\n#{"=" * 80}"
puts "TEST 3: Comparison (previously worked correctly)"
puts "=" * 80
tracer.trace("Which is taller, the Eiffel Tower or the Statue of Liberty?")
