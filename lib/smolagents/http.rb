# HTTP client utilities for agents.
#
# The Http module provides HTTP client functionality designed for agent use cases:
# thread-safe HTTP requests, user agent handling, and Ractor-safe clients for
# parallel agent execution.
#
# == Available Classes
#
# - {UserAgent} - Customizable user agent string generation
# - {RactorSafeClient} - HTTP client safe for use in Ractor contexts
#
# == Design Principles
#
# - **Simplicity**: Single-purpose classes for HTTP concerns
# - **Safety**: Thread-safe and Ractor-compatible clients
# - **Isolation**: No global state shared between agents
#
# @example Using the Ractor-safe client
#   client = Smolagents::Http::RactorSafeClient.new(timeout: 10)
#   response = client.get("https://example.com/api")
#
# @example Custom user agent
#   ua = Smolagents::Http::UserAgent.new(library_version: "2.0.0")
#   custom_agent = ua.to_s  # => "Smolagents/2.0.0 ..."
#
# @see Http::UserAgent For user agent customization
# @see Http::RactorSafeClient For thread/Ractor-safe HTTP requests
module Smolagents
  module Http
  end
end

# Load HTTP-related classes into the Smolagents::Http module
require_relative "http/user_agent"
require_relative "http/ractor_safe_client"
