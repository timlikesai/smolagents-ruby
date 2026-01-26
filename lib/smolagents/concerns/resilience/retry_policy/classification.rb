module Smolagents
  module Concerns
    # Error classification constants for retry decisions.
    #
    # Defines which errors are transient (retriable) vs permanent.
    # Use RetryPolicy#retriable? for actual classification logic.
    #
    # @example Using constants for custom policies
    #   policy = RetryPolicy.new(
    #     retryable_errors: RetryPolicyClassification::RETRIABLE_ERRORS + [MyCustomError],
    #     ...
    #   )
    #
    # @see Types::RetryPolicy#retriable? For classification logic
    module RetryPolicyClassification
      # Errors that are transient and worth retrying.
      # Used as default retryable_errors in RetryPolicy.
      RETRIABLE_ERRORS = [
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        Faraday::ServerError, # 5xx errors
        RateLimitError,
        ServiceUnavailableError
      ].freeze

      # Errors that indicate permanent failures (never retry).
      NON_RETRIABLE_ERRORS = [
        Faraday::ClientError,
        AgentConfigurationError,
        PromptInjectionError,
        MCPConnectionError
      ].freeze

      # HTTP status codes that indicate retriable errors.
      # 408: Request Timeout, 429: Too Many Requests
      # 500: Internal Server Error, 502: Bad Gateway
      # 503: Service Unavailable, 504: Gateway Timeout
      RETRIABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504].freeze

      # Check if HTTP status code is retriable.
      #
      # @param code [Integer] HTTP status code
      # @return [Boolean] True if status is retriable
      def self.retriable_status?(code)
        RETRIABLE_STATUS_CODES.include?(code)
      end
    end
  end
end
