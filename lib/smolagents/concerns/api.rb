require "retriable"

module Smolagents
  module Concerns
    # Provides resilient API call patterns with retry, circuit breaking, and auditing.
    #
    # The Api concern combines circuit breaker protection, retry logic, and
    # audit logging into a single api_call method. Used by model classes
    # to make reliable calls to external LLM APIs.
    #
    # @example Basic API call with retries
    #   response = api_call(service: "openai", operation: "chat") do
    #     @client.chat(parameters: params)
    #   end
    #
    # @example With custom retryable errors
    #   response = api_call(
    #     service: "anthropic",
    #     operation: "messages",
    #     retryable_errors: [Faraday::Error, Anthropic::Error],
    #     tries: 5
    #   ) do
    #     @client.messages(parameters: params)
    #   end
    #
    # @example Validating response success
    #   response = make_http_request
    #   require_success!(response, message: "Search failed")
    #
    # @see CircuitBreaker Underlying circuit breaker implementation
    # @see Auditable Audit logging for API calls
    module Api
      include CircuitBreaker
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

      # Executes an API call with circuit breaker, retry, and audit logging.
      #
      # Wraps the given block with:
      # 1. Circuit breaker - fails fast if service is down
      # 2. Audit logging - records the call for debugging
      # 3. Retry logic - retries on specified errors with exponential backoff
      #
      # @param service [String] Service name for circuit and audit (e.g., "openai")
      # @param operation [String] Operation name for audit (e.g., "chat")
      # @param retryable_errors [Array<Class>] Error classes that trigger retry
      # @param tries [Integer] Maximum retry attempts (default: 3)
      # @yield Block that performs the actual API call
      # @return [Object] Result of the block
      # @raise [AgentGenerationError] When circuit is open
      # @raise [StandardError] When all retries exhausted
      def api_call(service:, operation:, retryable_errors: [], tries: 3, &)
        with_circuit_breaker("#{service}_api") do
          with_audit_log(service: service, operation: operation) do
            Retriable.retriable(tries: tries, base_interval: 1.0, max_interval: 30.0, on: retryable_errors, &)
          end
        end
      end
    end
  end
end
