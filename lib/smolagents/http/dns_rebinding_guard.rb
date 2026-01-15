require "faraday"
require "resolv"
require "ipaddr"
require_relative "ssrf_protection"

module Smolagents
  module Http
    # Faraday middleware that prevents DNS rebinding attacks.
    #
    # DNS rebinding is an attack where a malicious DNS server returns different
    # IPs for the same hostname between validation and connection time. This
    # middleware re-resolves the hostname at connection time and validates
    # that the IP hasn't changed to a private/internal address.
    #
    # @example Attack scenario prevented
    #   # 1. Attacker's DNS: evil.com -> 1.2.3.4 (public IP, passes validation)
    #   # 2. Short TTL expires
    #   # 3. Attacker's DNS: evil.com -> 169.254.169.254 (cloud metadata!)
    #   # 4. This middleware catches the rebind and raises ForbiddenError
    #
    # @see SsrfProtection Initial validation that caches the resolved IP
    class DnsRebindingGuard < Faraday::Middleware
      def initialize(app, resolved_ip: nil)
        super(app)
        @resolved_ip = resolved_ip
      end

      # Validates the request against DNS rebinding attacks.
      #
      # Performs hostname resolution at request time and compares the IP to the
      # one cached during URL validation. If the IP has changed to a private or
      # internal address, raises ForbiddenError to prevent TOCTOU attacks.
      #
      # @param env [Faraday::RequestEnv] Faraday request environment
      # @return [Faraday::Response] The response from the next middleware
      # @raise [Faraday::ForbiddenError] If DNS rebinding is detected
      def call(env)
        validate_ip_unchanged!(env) if @resolved_ip
        @app.call(env)
      end

      private

      def validate_ip_unchanged!(env)
        current_ip = resolve_host(env.url.host)
        return unless current_ip && current_ip != @resolved_ip

        validate_ip!(current_ip, env.url.host)
      end

      def resolve_host(host)
        Resolv.getaddress(host)
      rescue Resolv::ResolvError
        nil
      end

      def validate_ip!(ip_str, host)
        ip = IPAddr.new(ip_str)
        return unless SsrfProtection.private_ip?(ip)

        raise Faraday::ForbiddenError,
              "DNS rebinding detected: #{host} resolved to private IP #{ip_str}"
      end
    end
  end
end
