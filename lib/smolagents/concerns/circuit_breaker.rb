# frozen_string_literal: true

require "stoplight"

module Smolagents
  module Concerns
    # Circuit breaker pattern for API calls to fail fast when services are unhealthy.
    # Uses the stoplight gem to track failures and automatically open the circuit
    # after a threshold of failures, preventing wasted API calls and costs.
    module CircuitBreaker
      # Wraps a block with circuit breaker protection.
      #
      # @param name [String] Unique name for this circuit breaker
      # @param threshold [Integer] Number of failures before opening circuit (default: 3)
      # @param cool_off [Integer] Seconds to wait before attempting to close circuit (default: 30)
      # @yield The block to execute with circuit breaker protection
      # @return The result of the block if successful
      # @raise [AgentGenerationError] If circuit is open (service unavailable)
      def with_circuit_breaker(name, threshold: 3, cool_off: 30, &block)
        light = Stoplight(name)
          .with_threshold(threshold)
          .with_cool_off_time(cool_off)
        
        light.run(&block)
      rescue Stoplight::Error::RedLight => e
        raise AgentGenerationError, "Service unavailable (circuit open): #{name}"
      end
    end
  end
end
