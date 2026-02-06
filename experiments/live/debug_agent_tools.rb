#!/usr/bin/env ruby
# Debug agent tool calling to understand step structure

require_relative "lib/bootstrap"
require_relative "eval/lib/tools"

puts "=" * 60
puts "Debug Agent Tool Calling"
puts "=" * 60

endpoint = LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4
model_id = "granite-4.0-h-small"

puts "Endpoint: #{endpoint}"
puts "Model: #{model_id}"

# Build model without builder (simpler)
model = Smolagents::Models::OpenAIModel.new(
  model_id: model_id,
  api_base: endpoint,
  api_key: "not-needed",
  temperature: 0.3,
  max_tokens: 512
)

# Build tool
calculator = LiveExperiments::Eval::Tools::Calculator.new
puts "Tool: #{calculator.class.tool_name}"

# Build agent
agent = Smolagents.agent
  .model { model }
  .tools(calculator)
  .max_steps(5)
  .build

puts "\nRunning agent..."

result = agent.run("Use the calculator to compute 15 * 7")

puts "\n--- Result ---"
puts "State: #{result.state}"
puts "Output: #{result.output}"
puts "Steps: #{result.steps.size}"

puts "\n--- Step Details ---"
result.steps.each_with_index do |step, i|
  puts "\nStep #{i + 1}:"
  puts "  Class: #{step.class}"
  puts "  Methods: #{(step.methods - Object.methods).sort.join(", ")}"

  if step.respond_to?(:tool_calls)
    puts "  tool_calls: #{step.tool_calls.inspect}"
  else
    puts "  (no tool_calls method)"
  end

  if step.respond_to?(:action_output)
    puts "  action_output: #{step.action_output.inspect}"
  end

  if step.respond_to?(:message)
    msg = step.message
    puts "  message.tool_calls: #{msg.tool_calls.inspect}" if msg.respond_to?(:tool_calls)
  end

  if step.respond_to?(:model_output_message)
    msg = step.model_output_message
    if msg
      puts "  model_output_message class: #{msg.class}"
      puts "  model_output_message.tool_calls: #{msg.tool_calls.inspect}" if msg.respond_to?(:tool_calls)
    end
  end

  if step.respond_to?(:code_action)
    puts "  code_action: #{step.code_action.inspect}"
  end
end
