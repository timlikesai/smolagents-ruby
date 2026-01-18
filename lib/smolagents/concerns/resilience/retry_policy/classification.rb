module Smolagents
  module Concerns
    # Error classification for retry decisions.
    #
    # Categorizes errors as retriable (transient) or non-retriable (permanent)
    # to determine whether retry attempts are worthwhile.
    #
    # @example Checking if an error is retriable
    #   RetryPolicyClassification.retriable?(Faraday::TimeoutError.new)  #=> true
    #   RetryPolicyClassification.retriable?(AuthenticationError.new)     #=> false
    module RetryPolicyClassification
      # Errors that are transient and worth retrying
      RETRIABLE_ERRORS = [
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        RateLimitError,
        ServiceUnavailableError
      ].freeze

      # Errors that indicate permanent failures
      NON_RETRIABLE_ERRORS = [
        Faraday::ClientError,
        AgentConfigurationError,
        PromptInjectionError,
        MCPConnectionError
      ].freeze

      # HTTP status codes that are retriable
      RETRIABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504].freeze

      class << self
        # Documents methods provided by this module.
        # @return [Hash<Symbol, String>] Method name to description mapping
        def provided_methods
          {
            retriable?: "Check if an error should trigger retry",
            retriable_status?: "Check if HTTP status code is retriable"
          }
        end

        # Checks if an error is retriable based on classification.
        #
        # @param error [StandardError] The error to check
        # @return [Boolean] True if the error is transient
        def retriable?(error)
          return true if RETRIABLE_ERRORS.any? { |klass| error.is_a?(klass) }
          return false if NON_RETRIABLE_ERRORS.any? { |klass| error.is_a?(klass) }

          retriable_by_status?(error)
        end

        # Check if HTTP status code indicates a retriable error.
        #
        # @param code [Integer] HTTP status code
        # @return [Boolean] True if status is retriable
        def retriable_status?(code)
          RETRIABLE_STATUS_CODES.include?(code)
        end

        private

        def retriable_by_status?(error)
          status = extract_status_code(error)
          status ? retriable_status?(status) : false
        end

        def extract_status_code(error)
          if error.respond_to?(:response) && error.response.respond_to?(:status)
            error.response.status
          elsif error.respond_to?(:status_code)
            error.status_code
          end
        end
      end
    end
  end
end
