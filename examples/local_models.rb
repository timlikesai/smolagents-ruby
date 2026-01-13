#!/usr/bin/env ruby
# frozen_string_literal: true

# Local Models Example
#
# A complete guide to using smolagents with local LLM servers:
# - LM Studio
# - Ollama
# - llama.cpp
# - vLLM
# - text-generation-webui
#
# Usage:
#   # Start your local server first, then:
#   ruby examples/local_models.rb

require "smolagents"

# =============================================================================
# LM Studio (Default port: 1234)
# =============================================================================
#
# LM Studio provides an OpenAI-compatible API out of the box.
# Start LM Studio, load a model, and start the local server.

puts "=" * 70
puts "LM STUDIO"
puts "=" * 70

lm_studio = Smolagents::OpenAIModel.lm_studio(
  "gemma-3n-e4b-it-q8_0",  # From unsloth/gemma-3n-E4B-it-GGUF
  host: "localhost",
  port: 1234
)

puts "Configured: #{lm_studio.model_id}"
puts "Endpoint: http://localhost:1234/v1"

# Or with full control:
lm_studio_custom = Smolagents::OpenAIModel.new(
  model_id: "gpt-oss-20b-mxfp4",  # From unsloth/gpt-oss-20b-GGUF
  api_base: "http://localhost:1234/v1",
  api_key: "not-needed",
  temperature: 0.7,
  max_tokens: 2048
)

# =============================================================================
# Ollama (Default port: 11434)
# =============================================================================
#
# Ollama provides an OpenAI-compatible endpoint at /v1.
# Install Ollama and run: ollama run llama3

puts "\n" + "=" * 70
puts "OLLAMA"
puts "=" * 70

ollama = Smolagents::OpenAIModel.ollama("gemma-3n-e4b-it-q8_0")

puts "Configured: #{ollama.model_id}"
puts "Endpoint: http://localhost:11434/v1"

# With Nemotron model (via ik_llama format):
ollama_nemotron = Smolagents::OpenAIModel.ollama(
  "nemotron-3-nano-30b-a3b-iq4_nl",
  host: "localhost",
  port: 11434
)

# =============================================================================
# llama.cpp (Default port: 8080)
# =============================================================================
#
# Run llama.cpp with the --server flag:
# ./llama-server -m gpt-oss-120b-mxfp4.gguf -c 8192 --port 8080

puts "\n" + "=" * 70
puts "LLAMA.CPP"
puts "=" * 70

llama_cpp = Smolagents::OpenAIModel.llama_cpp("gpt-oss-120b-mxfp4")  # From unsloth/gpt-oss-120b-GGUF

puts "Configured: #{llama_cpp.model_id}"
puts "Endpoint: http://localhost:8080/v1"

# =============================================================================
# vLLM (Default port: 8000)
# =============================================================================
#
# Run vLLM with:
# python -m vllm.entrypoints.openai.api_server --model unsloth/gpt-oss-20b-GGUF

puts "\n" + "=" * 70
puts "VLLM"
puts "=" * 70

vllm = Smolagents::OpenAIModel.vllm("gpt-oss-20b-mxfp4")

puts "Configured: #{vllm.model_id}"
puts "Endpoint: http://localhost:8000/v1"

# =============================================================================
# Remote Server via Tailscale
# =============================================================================
#
# Access a model running on another machine via Tailscale:

puts "\n" + "=" * 70
puts "REMOTE SERVER (TAILSCALE)"
puts "=" * 70

remote = Smolagents::OpenAIModel.new(
  model_id: "local-model",
  api_base: "http://my-server.tailnet-name.ts.net:1234/v1",
  api_key: "not-needed"
)

puts "Configured for remote access via Tailscale"
puts "Endpoint: http://my-server.tailnet-name.ts.net:1234/v1"

# =============================================================================
# Building an Agent with Local Model
# =============================================================================

puts "\n" + "=" * 70
puts "BUILDING AN AGENT"
puts "=" * 70

# Choose your local model:
local_model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")

# Build an agent optimized for local models:
# - Use tool_calling agent (simpler than code agent)
# - Fewer max_steps (local models can be slower)
# - Focused tool set

agent = Smolagents.agent(:tool_calling)
  .model { local_model }
  .tools(:duckduckgo_search, :final_answer)
  .max_steps(5)
  .instructions("Be concise. Use search when needed.")
  .on(:after_step) do |step:, monitor:|
    puts "  Step #{step.step_number}: #{monitor.duration.round(1)}s"
  end
  .build

puts "\nAgent configured with:"
puts "  Type: tool_calling"
puts "  Tools: #{agent.tools.keys.join(', ')}"
puts "  Max steps: #{agent.max_steps}"

# =============================================================================
# Testing Your Connection
# =============================================================================

puts "\n" + "=" * 70
puts "CONNECTION TEST"
puts "=" * 70

def test_connection(model, name)
  print "Testing #{name}... "

  message = Smolagents::ChatMessage.user("Say 'hello' in one word.")
  response = model.generate([message], max_tokens: 10)

  puts "OK! Response: #{response.content.strip}"
  true
rescue Faraday::ConnectionFailed
  puts "FAILED (connection refused - is the server running?)"
  false
rescue StandardError => e
  puts "FAILED (#{e.class}: #{e.message})"
  false
end

# Uncomment to test your local server:
# test_connection(lm_studio, "LM Studio")
# test_connection(ollama, "Ollama")
# test_connection(llama_cpp, "llama.cpp")

puts "\nTo test: Uncomment the test_connection lines above"
puts "Make sure your local server is running first!"

# =============================================================================
# Running an Agent
# =============================================================================

puts "\n" + "=" * 70
puts "RUNNING AN AGENT"
puts "=" * 70

puts <<~INSTRUCTIONS

  To run an agent with a local model:

  1. Start your local server (LM Studio, Ollama, llama.cpp)

  2. Create the model:
     model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")

  3. Build the agent:
     agent = Smolagents.agent(:tool_calling)
       .model { model }
       .tools(:web_search, :final_answer)
       .build

  4. Run:
     result = agent.run("Your question here")
     puts result.output

INSTRUCTIONS

# Example (uncomment when server is running):
#
# model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
# agent = Smolagents.agent(:tool_calling)
#   .model { model }
#   .tools(:duckduckgo_search, :final_answer)
#   .max_steps(5)
#   .build
#
# result = agent.run("What is the current Ruby version?")
# puts result.output

# =============================================================================
# Tips for Local Models
# =============================================================================

puts "=" * 70
puts "TIPS FOR LOCAL MODELS"
puts "=" * 70

puts <<~TIPS

  1. Use tool_calling agent type
     - Simpler than code agent
     - Works better with smaller models

  2. Keep tool sets small
     - 2-3 tools maximum
     - Reduces confusion for the model

  3. Use clear, simple prompts
     - Avoid complex multi-step instructions
     - Be specific about what you want

  4. Adjust max_steps
     - Fewer steps = faster completion
     - Start with 5, increase if needed

  5. Monitor performance
     - Use callbacks to track step duration
     - Consider caching for repeated queries

  6. Model recommendations:
     - Gemma 3n E4B q8_0: Excellent balance of speed/quality (unsloth/gemma-3n-E4B-it-GGUF)
     - GPT-OSS 20B MXFP4: Great for complex reasoning (unsloth/gpt-oss-20b-GGUF)
     - GPT-OSS 120B MXFP4: Best quality for demanding tasks (unsloth/gpt-oss-120b-GGUF)
     - Nemotron 3 Nano 30B A3B IQ4_NL: Fast and capable via ik_llama

TIPS

# =============================================================================
# Notes for Improvement
# =============================================================================
#
# TODO: Consider adding these features:
#
# 1. Auto-detection of local servers
#    model = Smolagents::OpenAIModel.auto_detect
#    # Tries common local ports in order
#
# 2. Health check method
#    model.healthy?  # Returns true if server is responding
#
# 3. Model info extraction
#    model.available_models  # Lists models on server
#
# 4. Performance profiling
#    model.benchmark("Hello")  # Returns tokens/sec
