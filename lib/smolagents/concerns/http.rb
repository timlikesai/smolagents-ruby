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

      def get(url, params: {}, headers: {}, allow_private: false)
        validate_url!(url, allow_private: allow_private)
        connection(url).get do |req|
          req.params.merge!(params)
          req.headers.merge!(headers)
        end
      end

      def post(url, body: nil, json: nil, headers: {}, allow_private: false)
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

      def connection(url)
        @_connections ||= {}
        @_connections[url] ||= Faraday.new(url: url) do |faraday|
          faraday.headers["User-Agent"] = @user_agent || DEFAULT_USER_AGENT
          faraday.options.timeout = @timeout || DEFAULT_TIMEOUT
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
