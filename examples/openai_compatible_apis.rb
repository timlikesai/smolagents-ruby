#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenAI-Compatible API Examples
# Demonstrates using OpenAIModel with LM Studio, llama.cpp, vLLM, etc.

require "smolagents"
require "smolagents/models/openai_model"

# =============================================================================
# 1. LM Studio (Local OpenAI-compatible server)
# =============================================================================

puts "=" * 80
puts "Example 1: LM Studio (with convenience method)"
puts "=" * 80

# Easy way: Use the convenience method!
lm_studio_model = Smolagents::OpenAIModel.lm_studio("local-model")

puts "LM Studio model configured (easy way):"
puts "  Model ID: #{lm_studio_model.model_id}"
puts "  API Base: http://localhost:1234/v1"
puts "  Ready to use with agents!"

# Manual way (still supported):
manual_model = Smolagents::OpenAIModel.new(
  model_id: "local-model",
  api_base: "http://localhost:1234/v1",
  api_key: "not-needed",
  temperature: 0.7,
  max_tokens: 1000
)

puts "\nOr use the manual method if you need custom settings."

# =============================================================================
# 2. All Convenience Methods
# =============================================================================

puts "\n" + "=" * 80
puts "Example 2: All Convenience Methods"
puts "=" * 80

# LM Studio (port 1234)
lm = Smolagents::OpenAIModel.lm_studio("local-model")
puts "LM Studio: #{lm.model_id} @ localhost:1234"

# llama.cpp (port 8080)
llama = Smolagents::OpenAIModel.llama_cpp("llama-3")
puts "llama.cpp: #{llama.model_id} @ localhost:8080"

# vLLM (port 8000)
vllm = Smolagents::OpenAIModel.vllm("meta-llama/Llama-3-8b")
puts "vLLM: #{vllm.model_id} @ localhost:8000"

# Ollama (port 11434)
ollama = Smolagents::OpenAIModel.ollama("llama3")
puts "Ollama: #{ollama.model_id} @ localhost:11434"

# text-generation-webui (port 5000)
tgw = Smolagents::OpenAIModel.text_generation_webui("local-model")
puts "text-generation-webui: #{tgw.model_id} @ localhost:5000"

puts "\nAll convenience methods support host and port overrides!"
puts "Example: OpenAIModel.lm_studio('model', host: '192.168.1.100', port: 1235)"

# =============================================================================
# 3. vLLM (Production OpenAI-compatible server)
# =============================================================================

puts "\n" + "=" * 80
puts "Example 3: vLLM"
puts "=" * 80

# vLLM with custom endpoint
vllm_model = Smolagents::OpenAIModel.new(
  model_id: "meta-llama/Llama-3-8b-chat-hf",
  api_base: "http://your-vllm-server:8000/v1",
  api_key: "optional-api-key",
  temperature: 0.8,
  max_tokens: 2048
)

puts "vLLM model configured:"
puts "  Model ID: #{vllm_model.model_id}"
puts "  API Base: http://your-vllm-server:8000/v1"

# =============================================================================
# 4. Ollama (via llama.cpp compatibility)
# =============================================================================

puts "\n" + "=" * 80
puts "Example 4: Ollama"
puts "=" * 80

# Ollama with OpenAI compatibility mode
ollama_model = Smolagents::OpenAIModel.new(
  model_id: "llama3",
  api_base: "http://localhost:11434/v1",
  api_key: "not-needed"
)

puts "Ollama model configured:"
puts "  Model ID: #{ollama_model.model_id}"
puts "  API Base: http://localhost:11434/v1"
puts "  Note: Requires Ollama with OpenAI compatibility"

# =============================================================================
# 5. Using with DSL
# =============================================================================

puts "\n" + "=" * 80
puts "Example 5: Using with Agent DSL"
puts "=" * 80

# Create agent with local model using DSL
puts "# Create agent with LM Studio:"
puts <<~RUBY
  agent = Smolagents.define_agent do
    use_model "local-model",
      provider: :openai,
      api_base: "http://localhost:1234/v1",
      api_key: "not-needed"

    tools :web_search, :final_answer
    max_steps 10
  end

  result = agent.run("What is Ruby?")
RUBY

# =============================================================================
# 6. Tailscale/Remote Servers
# =============================================================================

puts "\n" + "=" * 80
puts "Example 6: Remote OpenAI-compatible APIs"
puts "=" * 80

# Using Tailscale or VPN to connect to remote server
remote_model = Smolagents::OpenAIModel.new(
  model_id: "lfm2.5-1.2b-instruct",
  api_base: "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1",  # Tailscale hostname
  api_key: "not-needed",
  temperature: 0.7
)

puts "Remote LM Studio model configured:"
puts "  Model ID: #{remote_model.model_id}"
puts "  API Base: http://macbook-pro-m4.reverse-bull.ts.net:1234/v1"
puts "  Connection: Via Tailscale"

# =============================================================================
# 7. Testing Local Models
# =============================================================================

puts "\n" + "=" * 80
puts "Example 7: Testing Connection"
puts "=" * 80

puts <<~RUBY
  # Test if your local model is working:
  model = Smolagents::OpenAIModel.new(
    model_id: "local-model",
    api_base: "http://localhost:1234/v1",
    api_key: "not-needed"
  )

  begin
    response = model.generate([
      Smolagents::ChatMessage.user("Say 'Hello!'")
    ])
    puts "✓ Model working! Response: \#{response.content}"
  rescue => e
    puts "✗ Connection failed: \#{e.message}"
    puts "  Make sure your server is running!"
  end
RUBY

# =============================================================================
# 8. Configuration Comparison
# =============================================================================

puts "\n" + "=" * 80
puts "Configuration Quick Reference"
puts "=" * 80

configs = [
  {
    name: "OpenAI (Cloud)",
    api_base: nil,  # Uses default
    api_key: "sk-...",
    model_id: "gpt-4"
  },
  {
    name: "LM Studio",
    api_base: "http://localhost:1234/v1",
    api_key: "not-needed",
    model_id: "any-local-model"
  },
  {
    name: "llama.cpp",
    api_base: "http://localhost:8080/v1",
    api_key: "not-needed",
    model_id: "llama-3"
  },
  {
    name: "vLLM",
    api_base: "http://server:8000/v1",
    api_key: "optional",
    model_id: "meta-llama/..."
  },
  {
    name: "Ollama",
    api_base: "http://localhost:11434/v1",
    api_key: "not-needed",
    model_id: "llama3"
  },
  {
    name: "text-generation-webui",
    api_base: "http://localhost:5000/v1",
    api_key: "not-needed",
    model_id: "any"
  }
]

configs.each do |config|
  puts "\n#{config[:name]}:"
  puts "  api_base: #{config[:api_base] || '(default)'}"
  puts "  api_key: #{config[:api_key]}"
  puts "  model_id: #{config[:model_id]}"
end

# =============================================================================
puts "\n" + "=" * 80
puts "Key Points"
puts "=" * 80
puts <<~POINTS

  1. ANY OpenAI-compatible API works with OpenAIModel
  2. Set api_base to your server's URL
  3. Most local servers don't need real API keys
  4. Works with: LM Studio, llama.cpp, vLLM, Ollama, text-generation-webui
  5. Perfect for local development and testing
  6. Can use Tailscale for secure remote access

  Start your local server and give it a try!
POINTS
