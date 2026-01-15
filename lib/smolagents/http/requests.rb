require "json"
require "uri"
require_relative "ssrf_protection"
require_relative "connection"

module Smolagents
  module Http
    # HTTP request methods with SSRF protection.
    #
    # Provides GET and POST methods that validate URLs before making requests.
    # Depends on Connection module for Faraday client management.
    module Requests
      include Connection

      # Performs a GET request with SSRF protection.
      #
      # @param url [String] The URL to fetch
      # @param params [Hash] Query parameters to append
      # @param headers [Hash] Additional HTTP headers
      # @param allow_private [Boolean] If true, allows requests to private IP ranges
      # @return [Faraday::Response] The HTTP response
      # @raise [ArgumentError] If URL scheme is invalid or host is blocked
      def get(url, params: {}, headers: {}, allow_private: false)
        resolved_ip = validate_url!(url, allow_private:)
        connection(url, resolved_ip:, allow_private:).get do |req|
          req.params.merge!(params)
          req.headers.merge!(headers)
        end
      end

      # Performs a POST request with SSRF protection.
      #
      # @param url [String] The URL to post to
      # @param body [String, nil] Raw body content
      # @param json [Hash, nil] JSON body (automatically serialized and sets Content-Type)
      # @param form [Hash, nil] Form body (URL-encoded and sets Content-Type)
      # @param headers [Hash] Additional HTTP headers
      # @param allow_private [Boolean] If true, allows requests to private IP ranges
      # @return [Faraday::Response] The HTTP response
      # @raise [ArgumentError] If URL scheme is invalid or host is blocked
      def post(url, body: nil, json: nil, form: nil, headers: {}, allow_private: false)
        resolved_ip = validate_url!(url, allow_private:)
        connection(url, resolved_ip:, allow_private:).post do |req|
          req.headers.merge!(headers)
          set_post_body(req, body:, json:, form:)
        end
      end

      # Validates a URL for security concerns and resolves its IP.
      #
      # @param url [String] The URL to validate
      # @param allow_private [Boolean] If true, allows private IP ranges
      # @return [String, nil] The resolved IP address, or nil if allow_private
      # @raise [ArgumentError] If URL is invalid or blocked
      def validate_url!(url, allow_private: false)
        uri = URI.parse(url)
        SsrfProtection.validate_scheme!(uri)
        SsrfProtection.validate_not_blocked!(uri)
        return nil if allow_private

        SsrfProtection.resolve_and_validate_ip(uri)
      end

      private

      def set_post_body(req, body:, json:, form:)
        if json
          req.headers["Content-Type"] = "application/json"
          req.body = json.to_json
        elsif form
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form(form)
        else
          req.body = body
        end
      end
    end
  end
end
