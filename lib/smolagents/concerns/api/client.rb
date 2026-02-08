module Smolagents
  module Concerns
    # Provides API call patterns with circuit breaking, retry, and auditing.
    #
    # @example Basic API call with retries
    #   response = api_call(service: "openai", operation: "chat") do
    #     @client.chat(parameters: params)
    #   end
    #
    # @example With custom retry policy
    #   response = api_call(service: "openai", operation: "chat",
    #                       retry_policy: RetryPolicy.aggressive) do
    #     @client.chat(parameters: params)
    #   end
    #
    # @see CircuitBreaker Underlying circuit breaker implementation
    # @see Retryable Retry with backoff using RetryPolicy
    # @see Auditable Audit logging for API calls
    module ApiClient
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

      # Executes an API call with circuit breaker, retry with backoff, and audit logging.
      #
      # @param service [String] Service name for circuit and audit (e.g., "openai")
      # @param operation [String] Operation name for audit (e.g., "chat")
      # @param circuit_name [String, nil] Override circuit breaker name (default: "{service}_api")
      # @param retry_policy [RetryPolicy] Retry configuration (default: RetryPolicy.default)
      # @param circuit_threshold [Integer] Failures before circuit opens (default: 3)
      # @param circuit_cool_off [Integer] Seconds before circuit retries (default: 30)
      # @yield Block that performs the actual API call
      # @return [Object] Result of the block
      # @raise [AgentGenerationError] When circuit is open
      def api_call(service:, operation:, circuit_name: nil, retry_policy: Types::RetryPolicy.default,
                   circuit_threshold: 3, circuit_cool_off: 30, &)
        circuit = circuit_name || "#{service}_api"
        with_circuit_breaker(circuit, threshold: circuit_threshold, cool_off: circuit_cool_off) do
          with_audit_log(service:, operation:) do
            with_retry(policy: retry_policy, &)
          end
        end
      end
    end
  end
end
