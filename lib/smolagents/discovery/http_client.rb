require "net/http"
require "openssl"
require "logger"

module Smolagents
  module Discovery
    # HTTP utilities for local server discovery scanning.
    #
    # SSRF EXEMPTION: This module intentionally uses raw Net::HTTP without SSRF
    # protection for the following reasons:
    #
    # 1. LOCAL-ONLY BY DEFAULT: Scans only localhost ports (127.0.0.1) for known
    #    inference servers (LM Studio, Ollama, llama.cpp, vLLM, MLX-LM).
    #
    # 2. USER-CONTROLLED: Custom endpoints are explicitly configured by the user
    #    via SMOLAGENTS_ENDPOINTS env var or the Discovery.scan API. No untrusted
    #    input ever reaches this code.
    #
    # 3. NO ARBITRARY URLS: Unlike the main Http module (used by tools/agents),
    #    this module never processes URLs from agent outputs or tool responses.
    #
    # 4. SOCKET-LEVEL PROBING: The port_open? method requires raw Socket access
    #    that Faraday cannot provide.
    #
    # 5. SSL VERIFICATION DISABLED: Intentional for local dev servers that commonly
    #    use self-signed certificates.
    #
    # For HTTP requests that process untrusted URLs (e.g., from agent actions or
    # user-provided tool inputs), use Smolagents::Http::Requests instead.
    module HttpClient
      # Logger for discovery HTTP operations. Set to a Logger instance to enable
      # debug logging. Network errors during discovery are expected (most ports
      # won't have servers) and logged at DEBUG level.
      #
      # @example Enable debug logging
      #   Smolagents::Discovery::HttpClient.logger = Logger.new($stderr, level: :debug)
      @logger = nil

      class << self
        attr_accessor :logger
      end

      module_function

      def get(host:, port:, path:, timeout:, tls:, api_key: nil)
        uri = build_uri(host, port, path, tls)
        http = configure_http(uri, timeout, tls)
        request = build_request(uri, api_key)

        response = http.request(request)
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, SocketError, OpenSSL::SSL::SSLError => e
        log_network_error(host, port, path, e)
        nil
      end

      def log_network_error(host, port, path, error)
        return unless HttpClient.logger

        HttpClient.logger.debug do
          "[Discovery] Network error scanning #{host}:#{port}#{path}: #{error.class.name} - #{error.message}"
        end
      end

      def port_open?(host, port, timeout: 0.5)
        Socket.tcp(host, port, connect_timeout: timeout).close
        true
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
        false
      end

      def build_uri(host, port, path, tls)
        URI("#{tls ? "https" : "http"}://#{host}:#{port}#{path}")
      end

      def configure_http(uri, timeout, tls)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = tls
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if tls
        http
      end

      def build_request(uri, api_key)
        request = Net::HTTP::Get.new(uri.path)
        request["Authorization"] = "Bearer #{api_key}" if api_key
        request
      end
    end
  end
end
