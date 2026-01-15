require "stoplight"

module Smolagents
  module Concerns
    # Circuit breaker pattern for resilient API calls.
    #
    # Uses the Stoplight gem to implement circuit breaker functionality.
    # After a threshold of failures, the circuit opens and fails fast
    # until a cool-off period passes.
    #
    # Circuit states:
    # - GREEN: Normal operation, requests pass through
    # - YELLOW: Circuit recovering, testing if service is back
    # - RED: Circuit open, requests fail immediately
    #
    # @example Basic usage
    #   class MyApiTool < Tool
    #     include Concerns::CircuitBreaker
    #
    #     def execute(query:)
    #       with_circuit_breaker("my_api") do
    #         # ... make API call
    #       end
    #     end
    #   end
    #
    # @example Custom thresholds
    #   with_circuit_breaker("fragile_api", threshold: 2, cool_off: 60) do
    #     # Opens after 2 failures, waits 60 seconds before retrying
    #   end
    #
    # @example In Http concern integration
    #   # Circuit breakers are typically used inside safe_api_call
    #   safe_api_call do
    #     with_circuit_breaker("external_service") do
    #       get(url, params: params)
    #     end
    #   end
    #
    # @see Http#safe_api_call For error handling wrapper
    # @see https://github.com/bolshakov/stoplight Stoplight gem
    module CircuitBreaker
      # Execute a block with circuit breaker protection.
      # @param name [String] Unique identifier for this circuit
      # @param threshold [Integer] Number of failures before opening (default: 3)
      # @param cool_off [Integer] Seconds to wait before retrying (default: 30)
      # @yield Block to execute with circuit breaker protection
      # @return [Object] Result of the block
      # @raise [AgentGenerationError] When circuit is open (RED state)
      def with_circuit_breaker(name, threshold: 3, cool_off: 30, &)
        light = Stoplight(name)
                .with_threshold(threshold)
                .with_cool_off_time(cool_off)

        light.run(&)
      rescue Stoplight::Error::RedLight
        raise AgentGenerationError, "Service unavailable (circuit open): #{name}"
      end
    end
  end
end
