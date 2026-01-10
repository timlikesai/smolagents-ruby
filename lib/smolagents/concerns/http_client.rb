# frozen_string_literal: true

require "faraday"
require "json"

module Smolagents
  module Concerns
    # Shared HTTP client functionality for tools.
    module HttpClient
      DEFAULT_USER_AGENT = "Smolagents Ruby Agent/1.0"
      DEFAULT_TIMEOUT = 30

      def http_get(url, params: {}, headers: {})
        connection(url).get { |req| req.params.merge!(params); req.headers.merge!(headers) }
      end

      def http_post(url, body: nil, json: nil, headers: {})
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
