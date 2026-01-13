module Smolagents
  module Concerns
    # Provides API call patterns with circuit breaking, retry, and auditing.
    #
    # @example Basic API call with retries
    #   response = api_call(service: "openai", operation: "chat") do
    #     @client.chat(parameters: params)
    #   end
    #
    # @see CircuitBreaker Underlying circuit breaker implementation
    # @see Retryable Immediate retry without sleeping
    # @see Auditable Audit logging for API calls
    module Api
      include CircuitBreaker
      include Retryable
      include Auditable

      # Validates that a response was successful.
      #
      # @param response [Object] Response object with success? and status methods
      # @param message [String, nil] Custom error message (optional)
      # @raise [ApiError] When response indicates failure
      # @return [void]
      def require_success!(response, message: nil)
        return if response.success?

        raise ApiError.new(
          message || "API returned status #{response.status}",
          status_code: response.status,
          response_body: response.body
        )
      end

      # Executes an API call with circuit breaker, immediate retry, and audit logging.
      #
      # @param service [String] Service name for circuit and audit (e.g., "openai")
      # @param operation [String] Operation name for audit (e.g., "chat")
      # @param retryable_errors [Array<Class>] Error classes that trigger retry
      # @param tries [Integer] Maximum retry attempts (default: 3)
      # @yield Block that performs the actual API call
      # @return [Object] Result of the block
      # @raise [AgentGenerationError] When circuit is open
      def api_call(service:, operation:, retryable_errors: [], tries: 3, &)
        with_circuit_breaker("#{service}_api") do
          with_audit_log(service: service, operation: operation) do
            with_retry(on: retryable_errors, tries: tries, &)
          end
        end
      end
    end
  end
end
