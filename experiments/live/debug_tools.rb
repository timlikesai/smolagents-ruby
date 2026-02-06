#!/usr/bin/env ruby
# Debug tool calling to understand what's happening

require_relative "lib/bootstrap"
require_relative "eval/lib/tools"

puts "=" * 60
puts "Debug Tool Calling"
puts "=" * 60

endpoint = LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4
model_id = "granite-4.0-h-small"

puts "Endpoint: #{endpoint}"
puts "Model: #{model_id}"

# Build model without circuit breaker
model = Smolagents::Models::OpenAIModel.new(
  model_id: model_id,
  api_base: endpoint,
  api_key: "not-needed",
  temperature: 0.3,
  max_tokens: 512
)

puts "Model built: #{model.model_id}"

# Build tool
tool = LiveExperiments::Eval::Tools::Calculator.new
puts "Tool: #{tool.class.tool_name}"
puts "Tool schema: #{tool.class.inputs}"

# Create message
message = Smolagents::Types::ChatMessage.user("Use the calculator to compute 15 * 7")

puts "\nSending request with tools..."

begin
  response = model.generate([message], tools_to_call_from: [tool])
  puts "Response received!"
  puts "Content: #{response.content}"
  puts "Tool calls: #{response.tool_calls&.size || 0}"

  if response.tool_calls&.any?
    response.tool_calls.each do |tc|
      puts "  Tool: #{tc.name}(#{tc.arguments})"
    end
  end
rescue Faraday::BadRequestError => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts "Response body: #{e.response&.dig(:body)}"
  puts e.backtrace.first(5).join("\n")
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
