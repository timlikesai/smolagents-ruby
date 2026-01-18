module Smolagents
  module Errors
    # Error raised when model discovery operations fail.
    #
    # Provides structured error information for model query failures,
    # including factory methods for common error cases.
    #
    # @example Basic usage
    #   raise DiscoveryError, "Connection timeout"
    #
    # @example Using factory method
    #   raise DiscoveryError.model_query_failed("timeout after 10s")
    class DiscoveryError < AgentError
      # Creates a discovery error for failed model queries.
      #
      # @param message [String] The underlying error message
      # @return [DiscoveryError] A new error with formatted message
      def self.model_query_failed(message)
        new("Model discovery failed: #{message}")
      end

      # Creates a discovery error for cache refresh failures.
      #
      # @param message [String] The underlying error message
      # @return [DiscoveryError] A new error with formatted message
      def self.cache_refresh_failed(message)
        new("Failed to refresh model cache: #{message}")
      end

      # Creates a discovery error for endpoint not available.
      #
      # @param endpoint [String] The endpoint URL that was not available
      # @return [DiscoveryError] A new error with formatted message
      def self.endpoint_unavailable(endpoint)
        new("Model endpoint unavailable: #{endpoint}")
      end
    end
  end
end
