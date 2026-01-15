require_relative "../http"

module Smolagents
  module Concerns
    # Secure HTTP client concern with SSRF protection.
    #
    # Provides HTTP methods (get, post) with built-in security guards against:
    # - Server-Side Request Forgery (SSRF) via private IP blocking
    # - DNS rebinding attacks via IP validation caching
    # - Cloud metadata endpoint access (AWS, GCP, Azure)
    # - Time-of-check to time-of-use (TOCTOU) vulnerabilities
    #
    # Supports contextual User-Agent headers with agent/tool/model information
    # for AI transparency. See {Smolagents::Http::UserAgent} for details.
    #
    # @example Basic usage in a Tool
    #   class MyApiTool < Tool
    #     include Concerns::Http
    #
    #     def forward(url:)
    #       response = get(url)
    #       response.body
    #     end
    #   end
    #
    # @example With safe_api_call wrapper
    #   def forward(url:)
    #     safe_api_call do
    #       response = get(url, params: { format: "json" })
    #       parse_json_response(response)
    #     end
    #   end
    #
    # @example Allowing private IPs (internal tools only)
    #   response = get(url, allow_private: true)
    #
    # @see Smolagents::Http::SsrfProtection For SSRF protection details
    # @see Smolagents::Http::DnsRebindingGuard Faraday middleware for TOCTOU protection
    # @see Smolagents::Http::UserAgent RFC 7231 compliant User-Agent builder
    module Http
      include Smolagents::Http::Requests
      include Smolagents::Http::ResponseHandling

      # Re-export constants for backwards compatibility
      BLOCKED_HOSTS = Smolagents::Http::SsrfProtection::BLOCKED_HOSTS
      PRIVATE_RANGES = Smolagents::Http::SsrfProtection::PRIVATE_RANGES
      DEFAULT_USER_AGENT = Smolagents::Http::Connection::DEFAULT_USER_AGENT
      DEFAULT_TIMEOUT = Smolagents::Http::Connection::DEFAULT_TIMEOUT

      # Re-export class-level methods via delegation
      def self.validated_ips = Smolagents::Http::SsrfProtection.validated_ips
      def self.clear_validated_ips = Smolagents::Http::SsrfProtection.clear_validated_ips

      # Re-export DnsRebindingGuard for code that references it via this module
      DnsRebindingGuard = Smolagents::Http::DnsRebindingGuard
    end
  end
end
