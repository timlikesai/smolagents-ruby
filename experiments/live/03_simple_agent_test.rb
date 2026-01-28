#!/usr/bin/env ruby
# Test 03: Simple Agent with Tool
# ================================
# Goal: Verify a complete agent can run a task using a tool.
# This tests the full agent loop: prompt → model → code → tool → answer.
#
# Prerequisites:
# - Test 01 must pass (basic model communication)
# - Test 02 must pass (tool calling)
#
# Failure modes documented:
# - F07: Agent fails to extract code from model response
# - F08: Generated code fails to execute
# - F09: Agent exceeds max steps without answer
# - F10: final_answer not called correctly

require_relative "lib/bootstrap"
require "net/http"
require "json"

puts "=" * 60
puts "Test 03: Simple Agent with Tool"
puts "=" * 60

# Endpoint discovery
ENDPOINTS_TO_TRY = [
  { name: "localhost LM Studio", url: "http://localhost:1234/v1", model: nil },
  { name: "localhost llama.cpp", url: "http://localhost:8080/v1", model: nil },
  { name: "llama.cpp Ultra", url: "http://llama-cpp-ultra.reverse-bull.ts.net:8080/v1",
    model: "GLM-4.7-Flash-MXFP4_MOE" },
  { name: "MacBook Pro M4", url: LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4, model: nil },
  { name: "Mac Studio", url: LiveExperiments::Infrastructure::Endpoints::MAC_STUDIO, model: nil }
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

puts "\n[Selected] #{available_endpoint[:name]}"
puts "  Endpoint: #{endpoint}"
puts "  Model ID: #{model_id}"

# Step 1: Create the model
puts "\n[Step 1] Creating model..."
model = Smolagents::Models::OpenAIModel.new(
  model_id:,
  api_base: endpoint,
  api_key: "not-needed",
  temperature: 0.3,
  max_tokens: 1024
)
puts "  OK: #{model_id}"

# Step 2: Create a simple tool
puts "\n[Step 2] Creating calculator tool..."

class CalculatorTool < Smolagents::Tools::Tool
  self.tool_name = "calculator"
  self.description = "Performs basic arithmetic calculations. Returns the numeric result."
  self.inputs = { expression: { type: "string", description: "A math expression like '2 + 2' or '15 * 7'" } }
  self.output_type = "number"

  def execute(expression:)
    sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
    eval(sanitized) # rubocop:disable Security/Eval -- demo tool, input sanitized to digits/operators only
  rescue StandardError => e
    "Error: #{e.message}"
  end
end

tool = CalculatorTool.new
puts "  OK: #{tool.name}"

# Step 3: Build the agent
puts "\n[Step 3] Building agent..."
begin
  agent = Smolagents.agent
                    .model { model }
                    .tools(tool)
                    .max_steps(5)
                    .build

  puts "  OK: Agent built"
  puts "  Max steps: 5"
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  e.backtrace.first(5).each { |line| puts "    #{line}" }
  exit 1
end

# Step 4: Run the agent
task = "What is 25 times 4? Use the calculator and give me the final answer."
puts "\n[Step 4] Running agent..."
puts "  Task: #{task}"
puts "\n  Agent output:"
puts "  #{"-" * 50}"

start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  result = agent.run(task)
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

  puts "  #{"-" * 50}"
  puts "\n  Completed in #{elapsed}ms"
  puts "  Success: #{result.success?}"
  puts "  Output: #{result.output}"
  puts "  Steps taken: #{result.steps&.size || "unknown"}"

  if result.success?
    puts "\n#{"=" * 60}"
    puts "Test 03: PASSED"
    puts "=" * 60
  else
    puts "\n  Agent did not complete successfully"
    puts "  Final step: #{result.final_step&.class}"

    if result.steps&.any?
      puts "\n  Step details:"
      result.steps.each_with_index do |step, i|
        puts "    [#{i}] #{step.class.name.split("::").last}"
        puts "        #{step.respond_to?(:observations) ? step.observations&.first(100) : "no observations"}"
      end
    end

    puts "\n#{"=" * 60}"
    puts "Test 03: FAILED"
    puts "=" * 60
    exit 1
  end
rescue StandardError => e
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
  puts "  #{"-" * 50}"
  puts "\n  FAILED after #{elapsed}ms"
  puts "  Error class: #{e.class}"
  puts "  Error message: #{e.message}"
  puts "\n  Backtrace (first 15 lines):"
  e.backtrace.first(15).each { |line| puts "    #{line}" }

  puts "\n#{"=" * 60}"
  puts "Test 03: FAILED"
  puts "=" * 60
  exit 1
end
