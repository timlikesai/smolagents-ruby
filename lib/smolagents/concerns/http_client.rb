# frozen_string_literal: true

require "faraday"
require "json"
require "resolv"
require "ipaddr"

module Smolagents
  module Concerns
    # Shared HTTP client functionality for tools.
    module HttpClient
      DEFAULT_USER_AGENT = "Smolagents Ruby Agent/1.0"
      DEFAULT_TIMEOUT = 30

      # Cloud metadata endpoints that should always be blocked
      BLOCKED_HOSTS = Set.new(%w[
                                169.254.169.254
                                metadata.google.internal
                                metadata.goog
                              ]).freeze

      # Private IP ranges (RFC 1918, RFC 4193, etc.)
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

      def http_get(url, params: {}, headers: {}, allow_private: false)
        validate_url!(url, allow_private: allow_private)
        connection(url).get do |req|
          req.params.merge!(params)
          req.headers.merge!(headers)
        end
      end

      def http_post(url, body: nil, json: nil, headers: {}, allow_private: false)
        validate_url!(url, allow_private: allow_private)
        connection(url).post do |req|
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

        return if allow_private

        begin
          ip = IPAddr.new(Resolv.getaddress(uri.host))
          raise ArgumentError, "Private/internal IP addresses not allowed: #{uri.host}" if PRIVATE_RANGES.any? { |range| range.include?(ip) }
        rescue Resolv::ResolvError
          # Allow hostnames that don't resolve (might be valid later)
        rescue IPAddr::InvalidAddressError
          # Not a valid IP, allow (hostname will be resolved by HTTP client)
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

      def connection(url)
        @_connections ||= {}
        @_connections[url] ||= Faraday.new(url: url) do |f|
          f.headers["User-Agent"] = @user_agent || DEFAULT_USER_AGENT
          f.options.timeout = @timeout || DEFAULT_TIMEOUT
          f.adapter Faraday.default_adapter
        end
      end
    end

    # Rate limiting for API calls.
    module RateLimiter
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        attr_accessor :default_rate_limit
      end

      def setup_rate_limiter(rate_limit)
        @rate_limit = rate_limit
        @min_interval = rate_limit ? 1.0 / rate_limit : 0.0
        @last_request_time = 0.0
      end

      def enforce_rate_limit!
        return unless @rate_limit

        elapsed = Time.now.to_f - @last_request_time
        sleep(@min_interval - elapsed) if elapsed < @min_interval
        @last_request_time = Time.now.to_f
      end
    end

    # API key management and provider configuration.
    module ApiKeyManagement
      def require_api_key(key, env_var:, name: nil)
        api_key = key || ENV.fetch(env_var, nil)
        raise ArgumentError, "Missing API key: #{name || env_var}" unless api_key

        api_key
      end

      def optional_api_key(key, env_var:)
        key || ENV.fetch(env_var, nil)
      end

      def configure_provider(provider, providers, api_key: nil, required: true)
        config = providers.fetch(provider.to_s) { raise ArgumentError, "Unknown provider: #{provider}" }
        env_var = config[:key_env] || config[:env]
        resolved_key = required ? require_api_key(api_key, env_var: env_var) : optional_api_key(api_key, env_var: env_var)
        [config, resolved_key]
      end
    end
  end
end
