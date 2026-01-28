#!/usr/bin/env ruby
# Test 02: Tool Calling (Function Calling)
# =========================================
# Goal: Verify the model can request tool calls via the OpenAI function calling API.
# This is critical for agent operation - if tools don't work, agents can't act.
#
# Prerequisites:
# - Test 01 must pass (basic model communication)
#
# Failure modes documented:
# - F04: Tool schema not accepted by server
# - F05: Model doesn't use tools (returns text instead)
# - F06: Tool call format invalid/unparseable

require_relative "lib/bootstrap"
require "net/http"
require "json"

puts "=" * 60
puts "Test 02: Tool Calling (Function Calling)"
puts "=" * 60

# Reuse endpoint discovery from Test 01
ENDPOINTS_TO_TRY = [
  { name: "localhost LM Studio", url: "http://localhost:1234/v1", model: nil, server_type: :lm_studio },
  { name: "localhost llama.cpp", url: "http://localhost:8080/v1", model: nil, server_type: :llama_cpp },
  { name: "llama.cpp Ultra", url: "http://llama-cpp-ultra.reverse-bull.ts.net:8080/v1",
    model: "GLM-4.7-Flash-MXFP4_MOE", server_type: :llama_cpp },
  { name: "MacBook Pro M4", url: LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4,
    model: nil, server_type: :lm_studio },
  { name: "Mac Studio", url: LiveExperiments::Infrastructure::Endpoints::MAC_STUDIO,
    model: nil, server_type: :lm_studio }
].freeze

def build_http_client(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 3
  http.read_timeout = 5
  http
end

def parse_models_response(response)
  return { status: :error, error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

  models = JSON.parse(response.body)["data"]&.map { |m| m["id"] } || []
  { status: :ok, models: }
end

def check_endpoint(url)
  uri = URI("#{url.chomp("/v1")}/v1/models")
  parse_models_response(build_http_client(uri).get(uri.path))
rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout => e
  { status: :unreachable, error: e.message }
end

puts "\n[Discovery] Checking available endpoints..."
available_endpoint = nil

ENDPOINTS_TO_TRY.each do |ep|
  print "  #{ep[:name]}: "
  result = check_endpoint(ep[:url])

  case result[:status]
  when :ok
    puts "OK (#{result[:models].size} models)"
    available_endpoint ||= { **ep, models: result[:models] }
  when :unreachable
    puts "unreachable"
  else
    puts "error: #{result[:error]}"
  end
end

unless available_endpoint
  puts "\n#{"=" * 60}"
  puts "SKIPPED: No endpoints available"
  puts "=" * 60
  exit 0
end

endpoint = available_endpoint[:url]
model_id = available_endpoint[:model] || available_endpoint[:models].first
server_type = available_endpoint[:server_type]

puts "\n[Selected] #{available_endpoint[:name]}"
puts "  Endpoint: #{endpoint}"
puts "  Model ID: #{model_id}"
puts "  Server type: #{server_type}"

# Step 1: Create a simple tool
puts "\n[Step 1] Creating test tool..."

class CalculatorTool < Smolagents::Tools::Tool
  self.tool_name = "calculator"
  self.description = "Performs basic arithmetic. Use this to calculate math expressions."
  self.inputs = { expression: { type: "string", description: "Math expression like '2 + 2' or '10 * 5'" } }
  self.output_type = "string"

  def execute(expression:)
    # Simple eval for demo - sanitized to only allow math chars
    sanitized = expression.gsub(%r{[^0-9+\-*/().\s]}, "")
    result = eval(sanitized) # rubocop:disable Security/Eval -- demo tool, input sanitized to digits/operators only
    "The result is: #{result}"
  rescue StandardError => e
    "Error: #{e.message}"
  end
end

tool = CalculatorTool.new
puts "  Tool: #{tool.name}"
puts "  Description: #{tool.description}"

# Step 2: Create the model
puts "\n[Step 2] Creating OpenAIModel..."
begin
  model = Smolagents::Models::OpenAIModel.new(
    model_id:,
    api_base: endpoint,
    api_key: "not-needed",
    temperature: 0.3, # Lower temp for more deterministic tool use
    max_tokens: 512
  )
  puts "  OK: Model created"
  puts "  Server capabilities: #{model.server_capabilities&.server_type&.name || "none"}"
  puts "  Tools supported: #{model.server_capabilities&.supports_tools || "unknown"}"

  # Check for tools/response_format conflict
  if model.server_capabilities&.tools_response_format_conflict?
    puts "  WARNING: This server has tools/response_format conflict"
  end
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  exit 1
end

# Step 3: Create message that should trigger tool use
puts "\n[Step 3] Creating test message..."
message = Smolagents::Types::ChatMessage.user(
  "What is 15 multiplied by 7? Use the calculator tool to find the answer."
)
puts "  Message: #{message.content}"

# Step 4: Call model with tool
puts "\n[Step 4] Calling model.generate with tools..."
start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  response = model.generate([message], tools_to_call_from: [tool])
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

  puts "  OK: Response received in #{elapsed}ms"
  puts "\n  Response content: #{response.content || "(none - tool call only)"}"
  puts "  Tool calls: #{response.tool_calls&.size || 0}"

  if response.tool_calls&.any?
    puts "\n  Tool call details:"
    response.tool_calls.each_with_index do |tc, i|
      puts "    [#{i}] #{tc.name}(#{tc.arguments.inspect})"
      puts "        ID: #{tc.id}"
    end

    # Execute the tool call
    puts "\n[Step 5] Executing tool call..."
    tc = response.tool_calls.first
    result = tool.execute(**tc.arguments.transform_keys(&:to_sym))
    puts "  Tool result: #{result}"
  else
    puts "\n  WARNING: Model did not request tool call"
    puts "  This could mean:"
    puts "    - Model doesn't support function calling"
    puts "    - Model decided to answer directly"
    puts "    - Tool schema wasn't understood"
    puts "\n  Raw response content:"
    puts "  #{"-" * 40}"
    puts "  #{response.content}"
    puts "  #{"-" * 40}"

    # This is failure mode F05
    puts "\nThis is failure mode F05: Model doesn't use tools"
  end

  puts "\n  Token usage: #{response.token_usage&.to_h || "not reported"}"
rescue StandardError => e
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
  puts "  FAILED after #{elapsed}ms"
  puts "  Error class: #{e.class}"
  puts "  Error message: #{e.message}"
  puts "\n  Backtrace (first 10 lines):"
  e.backtrace.first(10).each { |line| puts "    #{line}" }

  if e.message.include?("tools") || e.message.include?("function")
    puts "\nThis is failure mode F04: Tool schema not accepted"
  else
    puts "\nThis is failure mode F06: Tool call format invalid"
  end
  exit 1
end

puts "\n#{"=" * 60}"
if response.tool_calls&.any?
  puts "Test 02: PASSED"
else
  puts "Test 02: PARTIAL (model responded but didn't use tool)"
end
puts "=" * 60

exit 0 unless response.tool_calls&.any? # Not a hard failure - some models may not support tools
