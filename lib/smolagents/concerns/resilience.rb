require_relative "resilience/retry_policy"
require_relative "resilience/retryable"
require_relative "resilience/circuit_breaker"
require_relative "resilience/rate_limiter"

module Smolagents
  module Concerns
    # Unified resilience concern composing rate limiting and circuit breaking.
    #
    # This concern provides a single include for tools that need both
    # rate limiting (to respect API limits) and circuit breaking (to
    # fail fast when services are down).
    #
    # @example Basic resilient API tool
    #   class MyApiTool < Tool
    #     include Concerns::Resilience
    #
    #     rate_limit 1.0  # 1 request per second
    #
    #     def execute(query:)
    #       resilient_call("my_api") do
    #         # ... make API call
    #       end
    #     end
    #   end
    #
    # @example With custom thresholds
    #   resilient_call("fragile_api", threshold: 2, cool_off: 60) do
    #     # Opens circuit after 2 failures, waits 60s
    #   end
    #
    # @see CircuitBreaker For circuit breaker details
    # @see RateLimiter For rate limiting details
    # @see Retryable For immediate retry logic
    # @see RetryPolicy For retry configuration
    module Resilience
      include CircuitBreaker
      include RateLimiter

      def self.included(base)
        base.extend(RateLimiter::ClassMethods)
      end

      # Execute a block with both rate limiting and circuit breaker protection.
      #
      # This is the primary method for resilient API calls. It:
      # 1. Enforces rate limits to respect API quotas
      # 2. Wraps the call in a circuit breaker for fail-fast behavior
      #
      # @param circuit_name [String] Unique identifier for the circuit
      # @param threshold [Integer] Failures before opening circuit (default: 3)
      # @param cool_off [Integer] Seconds to wait before retrying (default: 30)
      # @yield Block to execute with resilience protection
      # @return [Object] Result of the block
      # @raise [AgentGenerationError] When circuit is open
      def resilient_call(circuit_name, threshold: 3, cool_off: 30, &)
        enforce_rate_limit!
        with_circuit_breaker(circuit_name, threshold:, cool_off:, &)
      end
    end
  end
end
