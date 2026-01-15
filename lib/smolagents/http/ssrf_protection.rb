require "resolv"
require "ipaddr"

module Smolagents
  module Http
    # SSRF (Server-Side Request Forgery) protection utilities.
    #
    # Provides IP validation and blocking for cloud metadata endpoints
    # and private/internal IP ranges. Used by the HTTP concern to prevent
    # SSRF attacks when tools make HTTP requests.
    #
    # @see https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
    module SsrfProtection
      # Cloud metadata endpoints that are always blocked (SSRF prevention)
      # Covers AWS EC2/ECS, GCP, and Azure metadata services
      BLOCKED_HOSTS = Set.new(%w[
                                169.254.169.254
                                169.254.170.2
                                fd00:ec2::254
                                metadata.google.internal
                                metadata.goog
                              ]).freeze

      # Private and internal IP ranges blocked by default (RFC 1918, RFC 4193, etc.)
      PRIVATE_RANGES = [
        IPAddr.new("10.0.0.0/8"),       # RFC 1918 Class A private
        IPAddr.new("172.16.0.0/12"),    # RFC 1918 Class B private
        IPAddr.new("192.168.0.0/16"),   # RFC 1918 Class C private
        IPAddr.new("127.0.0.0/8"),      # Loopback
        IPAddr.new("169.254.0.0/16"),   # Link-local (APIPA)
        IPAddr.new("::1/128"),          # IPv6 loopback
        IPAddr.new("fc00::/7"),         # IPv6 unique local
        IPAddr.new("fe80::/10")         # IPv6 link-local
      ].freeze

      # Thread-local storage for validated IPs (TOCTOU mitigation).
      # @return [Hash<String, String>] Mapping of hostnames to validated IP addresses
      def self.validated_ips = Thread.current[:smolagents_validated_ips] ||= {}

      # Clears the validated IP cache (useful between requests or in tests)
      # @return [Hash] Empty hash
      def self.clear_validated_ips = Thread.current[:smolagents_validated_ips] = {}

      # Checks if an IP address is in a private/internal range.
      # @param ip [IPAddr] The IP address to check
      # @return [Boolean] true if IP is private/internal
      def self.private_ip?(ip) = PRIVATE_RANGES.any? { |range| range.include?(ip) }

      # Checks if a host is in the blocked hosts list.
      # @param host [String] The hostname to check
      # @return [Boolean] true if host is blocked
      def self.blocked_host?(host) = BLOCKED_HOSTS.include?(host&.downcase)

      # Validates URL scheme is HTTP or HTTPS.
      # @param uri [URI] The parsed URI
      # @raise [ArgumentError] If scheme is invalid
      def self.validate_scheme!(uri)
        return if %w[http https].include?(uri.scheme)

        raise ArgumentError, "Invalid URL scheme: #{uri.scheme}"
      end

      # Validates host is not a blocked cloud metadata endpoint.
      # @param uri [URI] The parsed URI
      # @raise [ArgumentError] If host is blocked
      def self.validate_not_blocked!(uri)
        return unless blocked_host?(uri.host)

        raise ArgumentError, "Blocked host: #{uri.host}"
      end

      # Resolves hostname and validates IP is not private/internal.
      # Caches the resolved IP for TOCTOU protection.
      #
      # @param uri [URI] The parsed URI
      # @return [String, nil] The resolved IP address, or nil on resolution failure
      # @raise [ArgumentError] If IP resolves to private/internal range
      def self.resolve_and_validate_ip(uri)
        ip_str = Resolv.getaddress(uri.host)
        ip = IPAddr.new(ip_str)

        raise ArgumentError, "Private/internal IP addresses not allowed: #{uri.host}" if private_ip?(ip)

        validated_ips[uri.host] = ip_str
        ip_str
      rescue Resolv::ResolvError, IPAddr::InvalidAddressError
        nil
      end
    end
  end
end
