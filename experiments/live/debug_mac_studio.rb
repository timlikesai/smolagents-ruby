#!/usr/bin/env ruby
# Debug Mac Studio Agent Issue
# The agent returned 200 instead of 100 for 25 * 4

require_relative "lib/bootstrap"

puts "=" * 60
puts "Debug: Mac Studio Agent"
puts "=" * 60

endpoint = LiveExperiments::Infrastructure::Endpoints::MAC_STUDIO
model_id = "glm-4.7-flash-mlx"

puts "Endpoint: #{endpoint}"
puts "Model: #{model_id}"

# Define calculator tool
class CalculatorTool < Smolagents::Tools::Tool
  self.tool_name = "calculator"
  self.description = "Performs arithmetic calculations"
  self.inputs = { expression: { type: "string", description: "Math expression" } }
  self.output_type = "number"

  def execute(expression:)
    puts "    [TOOL] calculator called with: #{expression.inspect}"
    sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
    result = eval(sanitized) # rubocop:disable Security/Eval -- debug
    puts "    [TOOL] result: #{result}"
    result
  rescue StandardError => e
    puts "    [TOOL] error: #{e.message}"
    0
  end
end

tool = CalculatorTool.new

model = Smolagents::Models::OpenAIModel.new(
  model_id:,
  api_base: endpoint,
  api_key: "not-needed",
  temperature: 0.3,
  max_tokens: 1024
)

# Subscribe to events for debugging
agent = Smolagents.agent
                  .model { model }
                  .tools(tool)
                  .max_steps(5)
                  .build

puts "\nRunning agent with task: What is 25 * 4?"
puts "-" * 60

result = agent.run("What is 25 * 4? Use the calculator tool and give the final answer.")

puts "-" * 60
puts "\nResult:"
puts "  Success: #{result.success?}"
puts "  Output: #{result.output}"
puts "  Steps: #{result.steps&.size}"

if result.steps
  puts "\nStep details:"
  result.steps.each_with_index do |step, i|
    puts "  [#{i}] #{step.class.name.split("::").last}"
    if step.respond_to?(:model_output_message)
      content = step.model_output_message&.content
      puts "      Model output: #{content&.[](0..200)}..." if content
    end
    if step.respond_to?(:observations)
      puts "      Observations: #{step.observations&.[](0..100)}"
    end
    if step.respond_to?(:action_output)
      puts "      Action output: #{step.action_output}"
    end
  end
end
