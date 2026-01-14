require "faraday"
require "json"
require "resolv"
require "ipaddr"
require_relative "../http/user_agent"

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
    # for AI transparency. See {Smolagents::UserAgent} for details.
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
    # @example With tool-specific User-Agent
    #   @user_agent = UserAgent.new(model_id: "gpt-4").with_tool("MyTool")
    #   response = get(url)  # User-Agent includes tool context
    #
    # @see DnsRebindingGuard Faraday middleware for TOCTOU protection
    # @see UserAgent RFC 7231 compliant User-Agent builder
    module Http
      # Default User-Agent for requests without explicit context
      DEFAULT_USER_AGENT = Smolagents::Http::UserAgent.new.freeze
      # Default request timeout in seconds
      DEFAULT_TIMEOUT = 30

      # @!attribute [rw] user_agent
      #   @return [UserAgent, String, nil] User-Agent for HTTP requests.
      #     Can be a UserAgent object (preferred), a String, or nil for default.
      attr_accessor :user_agent

      # Cloud metadata endpoints that are always blocked (SSRF prevention)
      BLOCKED_HOSTS = Set.new(%w[
                                169.254.169.254
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
      # Stores hostname => IP mappings validated at request time.
      # @return [Hash<String, String>] Mapping of hostnames to validated IP addresses
      def self.validated_ips
        Thread.current[:smolagents_validated_ips] ||= {}
      end

      # Clears the validated IP cache (useful between requests or in tests)
      # @return [Hash] Empty hash
      def self.clear_validated_ips
        Thread.current[:smolagents_validated_ips] = {}
      end

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

      # Validates a URL for security concerns and resolves its IP.
      #
      # Checks for:
      # - Valid HTTP/HTTPS scheme
      # - Not a blocked cloud metadata endpoint
      # - Not a private/internal IP (unless allow_private is true)
      #
      # Stores the resolved IP in thread-local cache for TOCTOU protection.
      #
      # @param url [String] The URL to validate
      # @param allow_private [Boolean] If true, allows private IP ranges
      # @return [String, nil] The resolved IP address, or nil if allow_private
      # @raise [ArgumentError] If URL is invalid or blocked
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

      # Parses a JSON response body, returning error hash on parse failure.
      #
      # @param response [Faraday::Response] The HTTP response
      # @return [Hash, Array] Parsed JSON data, or error hash if parsing fails
      def parse_json_response(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        { error: "JSON parse error: #{e.message}" }
      end

      # Converts HTTP errors to user-friendly messages.
      #
      # @param error [StandardError] The error to handle
      # @return [String] Human-readable error message
      def handle_http_error(error)
        case error
        when Faraday::TimeoutError then "The request timed out. Please try again later."
        else "Error: #{error.message}"
        end
      end

      # Wraps an HTTP operation with standardized error handling.
      #
      # Catches common HTTP and parsing errors, returning user-friendly
      # error messages instead of raising exceptions.
      #
      # @example
      #   safe_api_call do
      #     response = get(url)
      #     parse_json_response(response)
      #   end
      #
      # @yield Block containing HTTP operations
      # @return [Object] Result of block, or error string on failure
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
        @_connections[cache_key] ||= build_connection(url, resolved_ip:, allow_private:)
      end

      def build_connection(url, resolved_ip: nil, allow_private: false)
        Faraday.new(url:) do |faraday|
          faraday.headers["User-Agent"] = user_agent_string
          faraday.options.timeout = @timeout || DEFAULT_TIMEOUT

          # Add DNS rebinding guard middleware unless private IPs are allowed
          faraday.use DnsRebindingGuard, resolved_ip: resolved_ip unless allow_private

          faraday.adapter Faraday.default_adapter
        end
      end

      # Close all cached HTTP connections
      def close_connections
        return unless defined?(@_connections)

        @_connections&.each_value do |conn|
          conn.close if conn.respond_to?(:close)
        end
        @_connections = nil
      end

      def private_ip?(ip)
        PRIVATE_RANGES.any? { |range| range.include?(ip) }
      end

      # Converts @user_agent to string, handling both UserAgent objects and strings.
      # @return [String] User-Agent header value
      def user_agent_string
        case @user_agent
        when Smolagents::Http::UserAgent then @user_agent.to_s
        when String then @user_agent
        else DEFAULT_USER_AGENT.to_s
        end
      end

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
      # @see Http#validate_url! Initial validation that caches the resolved IP
      class DnsRebindingGuard < Faraday::Middleware
        def initialize(app, resolved_ip: nil)
          super(app)
          @resolved_ip = resolved_ip
        end

        # Validates the request environment against DNS rebinding attacks.
        #
        # Performs hostname resolution at request time and compares the IP to the
        # one cached during URL validation. If the IP has changed to a private or
        # internal address, raises ForbiddenError to prevent TOCTOU attacks.
        #
        # @param env [Faraday::RequestEnv] Faraday request environment
        # @return [Faraday::Response] The response from the next middleware
        # @raise [Faraday::ForbiddenError] If DNS rebinding is detected
        #
        # @example Normal request (IP unchanged)
        #   # Cached IP: 1.2.3.4
        #   # Current IP: 1.2.3.4
        #   # Result: Request proceeds
        #
        # @example Attack detected (IP rebind to private range)
        #   # Cached IP: 1.2.3.4
        #   # Current IP: 169.254.169.254 (metadata endpoint)
        #   # Result: ForbiddenError raised
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
