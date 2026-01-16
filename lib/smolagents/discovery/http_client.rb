require "net/http"
require "openssl"

module Smolagents
  module Discovery
    # HTTP utilities for discovery scanning.
    module HttpClient
      module_function

      def get(host:, port:, path:, timeout:, tls:, api_key: nil)
        uri = build_uri(host, port, path, tls)
        http = configure_http(uri, timeout, tls)
        request = build_request(uri, api_key)

        response = http.request(request)
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, SocketError, OpenSSL::SSL::SSLError
        nil
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
