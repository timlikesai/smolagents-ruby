require "uri"

module Smolagents
  module Discovery
    # Parses server URLs and environment configuration.
    module UrlParser
      module_function

      # Parses SMOLAGENTS_SERVERS environment variable.
      def parse_endpoints_env
        env_value = ENV.fetch("SMOLAGENTS_SERVERS", nil)
        return [] if env_value.nil? || env_value.empty?

        env_value.split(";").filter_map { |entry| parse_server_url(entry.strip) }
      end

      # Parses a single server URL into endpoint configuration.
      def parse_server_url(entry)
        url_str, api_key = split_url_and_key(entry)
        uri = URI.parse(url_str)
        return nil unless uri.host

        build_endpoint(uri, api_key)
      rescue URI::InvalidURIError
        nil
      end

      # Infers the server type from URL patterns.
      def infer_provider(uri)
        provider_from_port(uri.port) || provider_from_host(uri.host) || :openai_compatible
      end

      def split_url_and_key(entry)
        url_str, api_key = entry.split("|", 2)
        api_key = api_key&.strip
        api_key = nil if api_key&.empty?
        [url_str, api_key]
      end

      def build_endpoint(uri, api_key)
        tls = uri.scheme == "https"
        {
          provider: infer_provider(uri),
          host: uri.host,
          port: uri.port || (tls ? 443 : 80),
          tls:,
          api_key:
        }
      end

      def provider_from_port(port)
        { 1234 => :lm_studio, 11_434 => :ollama, 8000 => :vllm }[port]
      end

      def provider_from_host(host)
        host = host.downcase
        return :lm_studio if host.include?("lmstudio") || host.include?("lm-studio")
        return :ollama if host.include?("ollama")
        return :llama_cpp if host.include?("llama")

        nil
      end
    end
  end
end
