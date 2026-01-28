#!/usr/bin/env ruby
# Quick integration test for LM Studio 0.4.0 capability probing
# Run with: ruby experiments/live/lm_studio_probe_test.rb

# Load just the modules we need
require_relative "../../lib/smolagents/types/server_capability"
require_relative "../../lib/smolagents/concerns/resilience/lm_studio_probe"
require_relative "../../lib/smolagents/concerns/resilience/capability_detection"

puts "=" * 60
puts "LM Studio 0.4.0 Capability Probe Test"
puts "=" * 60

ENDPOINTS = {
  "MacBook Pro M4" => "http://macbook-pro-m4.reverse-bull.ts.net:1234",
  "Mac Studio" => "http://mac-studio.reverse-bull.ts.net:1234"
}.freeze

ENDPOINTS.each do |name, url|
  puts "\n#{name} (#{url})"
  puts "-" * 40

  result = Smolagents::Concerns::Resilience::LmStudioProbe.probe(url)

  if result.failed?
    puts "  ERROR: #{result.error}"
    next
  end

  puts "  Found #{result.models.size} models:"
  puts

  result.models.each do |model|
    tools_icon = model.tools_supported? ? "[tools]" : "       "
    vision_icon = model.vision_supported? ? "[vision]" : "        "
    ctx = model.max_context_length ? "#{(model.max_context_length / 1024.0).round}K ctx" : "unknown ctx"

    puts "  #{tools_icon} #{vision_icon} #{model.model_key}"
    puts "                      #{model.format} | #{model.architecture} | #{ctx}"
    puts
  end
end

puts "=" * 60
puts "Testing capability detection with model probing"
puts "=" * 60

# Test with a specific model
test_url = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1"
test_model = "qwen3-coder-30b"

puts "\nDetecting capabilities for #{test_model} at #{test_url}..."

# Create a simple detector class
detector = Class.new do
  include Smolagents::Concerns::Resilience::CapabilityDetection

  # Stub emit
  def emit(*); end
end.new

caps = detector.detect_capabilities(
  base_url: test_url,
  model_id: test_model
)

puts "\nCapabilities detected:"
puts "  supports_tools:     #{caps.supports_tools}"
puts "  supports_vision:    #{caps.supports_vision}"
puts "  supports_json_schema: #{caps.supports_json_schema}"
puts "  max_context_length: #{caps.max_context_length}"
puts "  confidence:         #{caps.confidence}"
puts "  probed?:            #{caps.probed?}"

puts "\n#{"=" * 60}"
puts "Done!"
