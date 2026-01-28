#!/usr/bin/env ruby
# Run All Tests Against All Endpoints
# ====================================
# Comprehensive test runner that validates all tests against all available hardware.

require_relative "lib/bootstrap"
require "net/http"
require "json"

puts "=" * 70
puts "Smolagents Live Integration Test Suite"
puts "=" * 70
puts "Time: #{Time.now}"
puts

# All known endpoints
ENDPOINTS = [
  {
    name: "llama.cpp Ultra",
    url: "http://llama-cpp-ultra.reverse-bull.ts.net:8080/v1",
    server_type: :llama_cpp,
    preferred_model: "GLM-4.7-Flash-MXFP4_MOE"
  },
  {
    name: "MacBook Pro M4 (LM Studio)",
    url: LiveExperiments::Infrastructure::Endpoints::MACBOOK_PRO_M4,
    server_type: :lm_studio,
    preferred_model: nil # Use first available
  },
  {
    name: "Mac Studio (LM Studio)",
    url: LiveExperiments::Infrastructure::Endpoints::MAC_STUDIO,
    server_type: :lm_studio,
    preferred_model: nil
  }
].freeze

def check_endpoint(url)
  uri = URI("#{url.chomp("/v1")}/v1/models")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 3
  http.read_timeout = 5

  response = http.get(uri.path)
  return { status: :error, error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

  models = JSON.parse(response.body)["data"]&.map { |m| m["id"] } || []
  { status: :ok, models: }
rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout => e
  { status: :unreachable, error: e.message }
end

# Discover available endpoints
puts "[Discovery] Checking endpoints..."
available_endpoints = []

ENDPOINTS.each do |ep|
  print "  #{ep[:name]}: "
  result = check_endpoint(ep[:url])

  case result[:status]
  when :ok
    puts "OK (#{result[:models].size} models)"
    available_endpoints << ep.merge(models: result[:models])
  when :unreachable
    puts "unreachable"
  else
    puts "error: #{result[:error]}"
  end
end

if available_endpoints.empty?
  puts "\nNo endpoints available. Exiting."
  exit 0
end

puts "\n#{available_endpoints.size} endpoint(s) available for testing."

# Test functions
def test_basic_model(endpoint, model_id)
  model = Smolagents::Models::OpenAIModel.new(
    model_id:,
    api_base: endpoint[:url],
    api_key: "not-needed",
    temperature: 0.7,
    max_tokens: 256
  )

  message = Smolagents::Types::ChatMessage.user("What is 2 + 2? Reply with just the number.")
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = model.generate([message])
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

  content = response.content.to_s.strip
  # Check if response contains "4"
  success = content.include?("4")

  { success:, elapsed:, content: content[0..50], tokens: response.token_usage&.total_tokens }
rescue StandardError => e
  { success: false, error: "#{e.class}: #{e.message}" }
end

def test_tool_calling(endpoint, model_id)
  # Define calculator tool inline
  tool_class = Class.new(Smolagents::Tools::Tool) do
    self.tool_name = "calculator"
    self.description = "Performs arithmetic calculations"
    self.inputs = { expression: { type: "string", description: "Math expression" } }
    self.output_type = "string"

    define_method(:execute) do |expression:|
      sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
      "Result: #{eval(sanitized)}" # rubocop:disable Security/Eval -- test only
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  tool = tool_class.new
  model = Smolagents::Models::OpenAIModel.new(
    model_id:,
    api_base: endpoint[:url],
    api_key: "not-needed",
    temperature: 0.3,
    max_tokens: 512
  )

  message = Smolagents::Types::ChatMessage.user("What is 15 * 7? Use the calculator tool.")
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = model.generate([message], tools_to_call_from: [tool])
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

  if response.tool_calls&.any?
    tc = response.tool_calls.first
    result = tool.execute(**tc.arguments.transform_keys(&:to_sym))
    { success: true, elapsed:, tool_called: tc.name, args: tc.arguments, result: }
  else
    { success: false, elapsed:, error: "No tool call", content: response.content&.[](0..50) }
  end
rescue StandardError => e
  { success: false, error: "#{e.class}: #{e.message}" }
end

def test_simple_agent(endpoint, model_id)
  # Define calculator tool
  tool_class = Class.new(Smolagents::Tools::Tool) do
    self.tool_name = "calculator"
    self.description = "Performs arithmetic calculations"
    self.inputs = { expression: { type: "string", description: "Math expression" } }
    self.output_type = "number"

    define_method(:execute) do |expression:|
      sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
      eval(sanitized) # rubocop:disable Security/Eval -- test only
    rescue StandardError
      0
    end
  end

  tool = tool_class.new
  model = Smolagents::Models::OpenAIModel.new(
    model_id:,
    api_base: endpoint[:url],
    api_key: "not-needed",
    temperature: 0.3,
    max_tokens: 1024
  )

  agent = Smolagents.agent
                    .model { model }
                    .tools(tool)
                    .max_steps(5)
                    .build

  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = agent.run("What is 25 * 4? Use calculator and give final answer.")
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

  {
    success: result.success?,
    elapsed:,
    output: result.output.to_s[0..50],
    steps: result.steps&.size || 0
  }
rescue StandardError => e
  { success: false, error: "#{e.class}: #{e.message[0..100]}" }
end

# Run all tests against all endpoints
results = {}

available_endpoints.each do |ep|
  puts "\n#{"=" * 70}"
  puts "Testing: #{ep[:name]}"
  puts "URL: #{ep[:url]}"
  puts "Server type: #{ep[:server_type]}"
  puts "=" * 70

  model_id = ep[:preferred_model] || ep[:models].first
  puts "Model: #{model_id}"

  results[ep[:name]] = {}

  # Test 1: Basic Model
  print "\n  [Test 01] Basic Model Communication... "
  $stdout.flush
  r = test_basic_model(ep, model_id)
  results[ep[:name]][:basic] = r
  if r[:success]
    puts "PASS (#{r[:elapsed]}ms, #{r[:tokens]} tokens)"
  else
    puts "FAIL: #{r[:error] || r[:content]}"
  end

  # Test 2: Tool Calling
  print "  [Test 02] Tool Calling... "
  $stdout.flush
  r = test_tool_calling(ep, model_id)
  results[ep[:name]][:tools] = r
  if r[:success]
    puts "PASS (#{r[:elapsed]}ms, called #{r[:tool_called]})"
  else
    puts "FAIL: #{r[:error] || "no tool call"}"
  end

  # Test 3: Simple Agent
  print "  [Test 03] Simple Agent... "
  $stdout.flush
  r = test_simple_agent(ep, model_id)
  results[ep[:name]][:agent] = r
  if r[:success]
    puts "PASS (#{r[:elapsed]}ms, #{r[:steps]} steps, output: #{r[:output]})"
  else
    puts "FAIL: #{r[:error]}"
  end
end

# Summary
puts "\n#{"=" * 70}"
puts "SUMMARY"
puts "=" * 70

total_pass = 0
total_fail = 0

results.each do |endpoint_name, tests|
  puts "\n#{endpoint_name}:"
  tests.each do |test_name, result|
    status = result[:success] ? "PASS" : "FAIL"
    result[:success] ? total_pass += 1 : total_fail += 1
    time = result[:elapsed] ? "#{result[:elapsed]}ms" : "N/A"
    puts "  #{test_name.to_s.ljust(10)} #{status.ljust(6)} #{time}"
  end
end

puts "\n" + "-" * 70
puts "Total: #{total_pass} passed, #{total_fail} failed"
puts "=" * 70

exit(total_fail.positive? ? 1 : 0)
