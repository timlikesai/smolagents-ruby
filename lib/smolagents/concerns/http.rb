require "faraday"
require "json"
require "resolv"
require "ipaddr"

module Smolagents
  module Concerns
    module Http
      DEFAULT_USER_AGENT = "Smolagents Ruby Agent/1.0".freeze
      DEFAULT_TIMEOUT = 30

      BLOCKED_HOSTS = Set.new(%w[
                                169.254.169.254
                                metadata.google.internal
                                metadata.goog
                              ]).freeze

      PRIVATE_RANGES = [
        IPAddr.new("10.0.0.0/8"),
        IPAddr.new("172.16.0.0/12"),
        IPAddr.new("192.168.0.0/16"),
        IPAddr.new("127.0.0.0/8"),
        IPAddr.new("169.254.0.0/16"),
        IPAddr.new("::1/128"),
        IPAddr.new("fc00::/7"),
        IPAddr.new("fe80::/10")
      ].freeze

      # Thread-local storage for validated IPs (TOCTOU mitigation)
      def self.validated_ips
        Thread.current[:smolagents_validated_ips] ||= {}
      end

      def self.clear_validated_ips
        Thread.current[:smolagents_validated_ips] = {}
      end

      def get(url, params: {}, headers: {}, allow_private: false)
        resolved_ip = validate_url!(url, allow_private: allow_private)
        connection(url, resolved_ip: resolved_ip, allow_private: allow_private).get do |req|
          req.params.merge!(params)
          req.headers.merge!(headers)
        end
      end

      def post(url, body: nil, json: nil, headers: {}, allow_private: false)
        resolved_ip = validate_url!(url, allow_private: allow_private)
        connection(url, resolved_ip: resolved_ip, allow_private: allow_private).post do |req|
          req.headers.merge!(headers)
          if json
            req.headers["Content-Type"] = "application/json"
            req.body = json.to_json
          else
            req.body = body
          end
        end
      end

      def validate_url!(url, allow_private: false)
        uri = URI.parse(url)
        raise ArgumentError, "Invalid URL scheme: #{uri.scheme}" unless %w[http https].include?(uri.scheme)
        raise ArgumentError, "Blocked host: #{uri.host}" if BLOCKED_HOSTS.include?(uri.host&.downcase)

        return nil if allow_private

        begin
          ip_str = Resolv.getaddress(uri.host)
          ip = IPAddr.new(ip_str)

          raise ArgumentError, "Private/internal IP addresses not allowed: #{uri.host}" if private_ip?(ip)

          # Store validated IP to prevent TOCTOU attacks
          Http.validated_ips[uri.host] = ip_str
          ip_str
        rescue Resolv::ResolvError, IPAddr::InvalidAddressError
          nil
        end
      end

      def parse_json_response(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        { error: "JSON parse error: #{e.message}" }
      end

      def handle_http_error(error)
        case error
        when Faraday::TimeoutError then "The request timed out. Please try again later."
        else "Error: #{error.message}"
        end
      end

      def safe_api_call
        yield
      rescue Faraday::TimeoutError => e
        handle_http_error(e)
      rescue Faraday::Error, JSON::ParserError => e
        "Error: #{e.message}"
      end

      private

      def connection(url, resolved_ip: nil, allow_private: false)
        # Use resolved IP as cache key to ensure IP consistency
        cache_key = resolved_ip ? "#{url}:#{resolved_ip}" : url

        @_connections ||= {}
        @_connections[cache_key] ||= build_connection(url, resolved_ip: resolved_ip, allow_private: allow_private)
      end

      def build_connection(url, resolved_ip: nil, allow_private: false)
        Faraday.new(url: url) do |faraday|
          faraday.headers["User-Agent"] = @user_agent || DEFAULT_USER_AGENT
          faraday.options.timeout = @timeout || DEFAULT_TIMEOUT

          # Add DNS rebinding guard middleware unless private IPs are allowed
          faraday.use DnsRebindingGuard, resolved_ip: resolved_ip unless allow_private

          faraday.adapter Faraday.default_adapter
        end
      end

      def private_ip?(ip)
        PRIVATE_RANGES.any? { |range| range.include?(ip) }
      end

      # Faraday middleware to prevent DNS rebinding attacks
      # Verifies the resolved IP at connection time matches the validated IP
      class DnsRebindingGuard < Faraday::Middleware
        def initialize(app, resolved_ip: nil)
          super(app)
          @resolved_ip = resolved_ip
        end

        def call(env)
          # Verify IP hasn't changed via DNS rebinding
          if @resolved_ip
            current_ip = resolve_host(env.url.host)
            if current_ip && current_ip != @resolved_ip
              # Re-validate the new IP to prevent rebinding to internal addresses
              validate_ip!(current_ip, env.url.host)
            end
          end

          @app.call(env)
        end

        private

        def resolve_host(host)
          Resolv.getaddress(host)
        rescue Resolv::ResolvError
          nil
        end

        def validate_ip!(ip_str, host)
          ip = IPAddr.new(ip_str)
          return unless PRIVATE_RANGES.any? { |range| range.include?(ip) }

          raise Faraday::ForbiddenError, "DNS rebinding detected: #{host} resolved to private IP #{ip_str}"
        end
      end
    end
  end
end
