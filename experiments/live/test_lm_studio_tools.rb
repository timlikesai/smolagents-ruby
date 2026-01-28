#!/usr/bin/env ruby
# Test LM Studio Native Tool Calling
# Try different models to see which support native function calling

require_relative "lib/bootstrap"

puts "=" * 60
puts "LM Studio Native Tool Calling Test"
puts "=" * 60

endpoint = LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4

# Models to test - prioritize ones likely to have function calling
MODELS_TO_TEST = [
  "lmstudio-community/qwen3-coder-30b-a3b-instruct-mlx",
  "zai-org/glm-4.7-flash",
  "nvidia/nemotron-3-nano",
  "granite-4.0-h-small"
].freeze

class CalculatorTool < Smolagents::Tools::Tool
  self.tool_name = "calculator"
  self.description = "Performs arithmetic calculations"
  self.inputs = { expression: { type: "string", description: "Math expression" } }
  self.output_type = "string"

  def execute(expression:)
    sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
    "Result: #{eval(sanitized)}" # rubocop:disable Security/Eval -- test
  rescue StandardError => e
    "Error: #{e.message}"
  end
end

tool = CalculatorTool.new

puts "\nEndpoint: #{endpoint}"
puts "Testing native function calling with different models...\n"

MODELS_TO_TEST.each do |model_id|
  puts "\n#{"-" * 60}"
  puts "Model: #{model_id}"
  puts "-" * 60

  begin
    model = Smolagents::Models::OpenAIModel.new(
      model_id:,
      api_base: endpoint,
      api_key: "not-needed",
      temperature: 0.3,
      max_tokens: 512
    )

    message = Smolagents::Types::ChatMessage.user(
      "What is 15 * 7? You MUST use the calculator tool to compute this."
    )

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = model.generate([message], tools_to_call_from: [tool])
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    puts "  Response time: #{elapsed}ms"
    puts "  Content: #{response.content&.[](0..100) || "(none)"}"
    puts "  Tool calls: #{response.tool_calls&.size || 0}"

    if response.tool_calls&.any?
      tc = response.tool_calls.first
      puts "  Tool: #{tc.name}(#{tc.arguments})"
      result = tool.execute(**tc.arguments.transform_keys(&:to_sym))
      puts "  Result: #{result}"
      puts "  STATUS: PASS - Native function calling works!"
    else
      puts "  STATUS: FAIL - Model did not use function calling API"
      puts "  (Model may have answered directly in content)"
    end
  rescue StandardError => e
    puts "  ERROR: #{e.class}: #{e.message}"
  end
end

puts "\n#{"=" * 60}"
puts "Done"
puts "=" * 60
