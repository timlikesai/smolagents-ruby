# HTTP client utilities for agents.
#
# The Http module provides HTTP client functionality designed for agent use cases:
# thread-safe HTTP requests, user agent handling, and SSRF protection.
#
# == Available Modules
#
# - {UserAgent} - Customizable user agent string generation
# - {SsrfProtection} - IP validation and blocked host management
# - {DnsRebindingGuard} - Faraday middleware for TOCTOU protection
# - {Connection} - Connection building and caching
# - {Requests} - GET/POST methods with SSRF protection
# - {ResponseHandling} - JSON parsing and error handling
#
# @see Http::UserAgent For user agent customization
# @see Http::SsrfProtection For SSRF protection utilities
module Smolagents
  module Http
  end
end

# Load HTTP-related modules into the Smolagents::Http module
require_relative "http/user_agent"
require_relative "http/ssrf_protection"
require_relative "http/dns_rebinding_guard"
require_relative "http/connection"
require_relative "http/requests"
require_relative "http/response_handling"
