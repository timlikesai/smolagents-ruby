require_relative "servers/llama_cpp"

module Smolagents
  # Server clients for inference server management.
  #
  # Provides abstractions for managing inference servers beyond simple
  # OpenAI-compatible API calls. Useful for:
  # - Querying server status and loaded models
  # - Managing model loading/unloading (where supported)
  # - Getting slot and resource information
  #
  # @example llama.cpp router mode (requires running server)
  #   # server = Smolagents::Servers::LlamaCpp.new(api_base: "https://my-server.example.com")
  #   # server.models.each { |m| puts "#{m.id}: #{m.status}" }
  #
  module Servers
  end
end
