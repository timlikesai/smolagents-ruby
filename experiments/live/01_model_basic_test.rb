#!/usr/bin/env ruby
# Test 01: Basic Model Communication
# ==================================
# Goal: Verify we can send a message and get a response from a local model.
# This is the foundation - if this fails, nothing else will work.
#
# Prerequisites:
# - LM Studio running on localhost:1234 OR
# - Tailscale connected with access to configured endpoints
#
# Failure modes documented:
# - F01: No endpoints reachable (network/Tailscale not connected)
# - F02: Endpoint reachable but model not loaded
# - F03: Model loaded but generation fails

require_relative "lib/bootstrap"
require "net/http"
require "json"

puts "=" * 60
puts "Test 01: Basic Model Communication"
puts "=" * 60

# Endpoint discovery - find first available endpoint
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
  print "  #{ep[:name]} (#{ep[:url]}): "
  result = check_endpoint(ep[:url])

  case result[:status]
  when :ok
    puts "OK (#{result[:models].size} models: #{result[:models].first(3).join(", ")}#{if result[:models].size > 3
                                                                                        "..."
                                                                                      end})"
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
  puts "\nTo run this test, ensure one of:"
  puts "  1. LM Studio is running on localhost:1234"
  puts "  2. Tailscale is connected with access to configured endpoints"
  puts "\nThis is failure mode F01: No endpoints reachable"
  exit 0 # Exit 0 - this is a valid skip, not a test failure
end

# Select model - use specified model or first available
endpoint = available_endpoint[:url]
model_id = available_endpoint[:model] || available_endpoint[:models].first

unless model_id
  puts "\n#{"=" * 60}"
  puts "SKIPPED: Endpoint available but no models loaded"
  puts "=" * 60
  puts "\nThis is failure mode F02: Endpoint reachable but no models"
  exit 0
end

puts "\n[Selected] #{available_endpoint[:name]}"
puts "  Endpoint: #{endpoint}"
puts "  Model ID: #{model_id}"

# Step 1: Create the model
puts "\n[Step 1] Creating OpenAIModel..."
begin
  model = Smolagents::Models::OpenAIModel.new(
    model_id:,
    api_base: endpoint,
    api_key: "not-needed",
    temperature: 0.7,
    max_tokens: 256 # Keep it short for testing
  )
  puts "  OK: Model created"
  puts "  Server capabilities: #{model.server_capabilities&.server_type&.name || "none detected"}"
rescue StandardError => e
  puts "  FAILED: #{e.class}: #{e.message}"
  puts "\nThis is failure mode F03: Model creation failed"
  exit 1
end

# Step 2: Create a simple message
puts "\n[Step 2] Creating test message..."
message = Smolagents::Types::ChatMessage.user("What is 2 + 2? Reply with just the number.")
puts "  Message: #{message.content}"

# Step 3: Send to model
puts "\n[Step 3] Calling model.generate..."
start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  response = model.generate([message])
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

  puts "  OK: Response received in #{elapsed}ms"
  puts "\n  Response content:"
  puts "  #{"-" * 40}"
  puts "  #{response.content}"
  puts "  #{"-" * 40}"
  puts "\n  Token usage: #{response.token_usage&.to_h || "not reported"}"
  puts "  Role: #{response.role}"
rescue StandardError => e
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
  puts "  FAILED after #{elapsed}ms"
  puts "  Error class: #{e.class}"
  puts "  Error message: #{e.message}"
  puts "\n  Backtrace (first 10 lines):"
  e.backtrace.first(10).each { |line| puts "    #{line}" }
  puts "\nThis is failure mode F03: Generation failed"
  exit 1
end

puts "\n#{"=" * 60}"
puts "Test 01: PASSED"
puts "=" * 60
