require "faraday"
require_relative "user_agent"
require_relative "dns_rebinding_guard"

module Smolagents
  module Http
    # HTTP connection building and caching.
    #
    # Provides Faraday connection management with proper User-Agent headers
    # and DNS rebinding protection middleware.
    module Connection
      # Default request timeout in seconds
      DEFAULT_TIMEOUT = 30

      # Default User-Agent for requests without explicit context
      DEFAULT_USER_AGENT = UserAgent.new.freeze

      # @!attribute [rw] user_agent
      #   @return [UserAgent, String, nil] User-Agent for HTTP requests.
      attr_accessor :user_agent

      private

      def connection(url, resolved_ip: nil, allow_private: false)
        cache_key = resolved_ip ? "#{url}:#{resolved_ip}" : url

        @_connections ||= {}
        @_connections[cache_key] ||= build_connection(url, resolved_ip:, allow_private:)
      end

      def build_connection(url, resolved_ip: nil, allow_private: false)
        Faraday.new(url:) do |faraday|
          faraday.headers["User-Agent"] = user_agent_string
          faraday.options.timeout = @timeout || DEFAULT_TIMEOUT
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

      # Converts @user_agent to string, handling UserAgent objects and strings.
      # @return [String] User-Agent header value
      def user_agent_string
        case @user_agent
        when UserAgent then @user_agent.to_s
        when String then @user_agent
        else DEFAULT_USER_AGENT.to_s
        end
      end
    end
  end
end
