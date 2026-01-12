# frozen_string_literal: true

require "retriable"

module Smolagents
  module Concerns
    module Api
      include CircuitBreaker
      include Auditable

      class ApiError < StandardError; end

      def require_success!(response, message: nil)
        return if response.success?

        raise ApiError, message || "API returned status #{response.status}"
      end

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
