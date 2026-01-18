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
    # Error categorization:
    # - CIRCUIT_BREAKING_ERRORS: True service failures that should trip the circuit
    # - NON_CIRCUIT_ERRORS: Local/recoverable errors that should NOT trip the circuit
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
      include Events::Emitter

      # Maps Stoplight color to circuit state symbol.
      STOPLIGHT_TO_STATE = {
        Stoplight::Color::GREEN => :closed,
        Stoplight::Color::YELLOW => :half_open,
        Stoplight::Color::RED => :open
      }.freeze
      # Errors that should NOT trip the circuit.
      # These are local issues or rate limits that should be handled differently:
      # - Encoding errors: Local issue, not service failure
      # - Rate limits: Use retry with backoff, not circuit breaker
      # - Code errors: Local code issue, not infrastructure
      NON_CIRCUIT_ERRORS = [
        JSON::GeneratorError,
        JSON::ParserError,
        RateLimitError,
        InterpreterError
      ].freeze

      # Execute a block with circuit breaker protection.
      #
      # Most errors count toward the circuit threshold.
      # Errors in NON_CIRCUIT_ERRORS are re-raised without affecting the circuit.
      #
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
                .with_error_handler { |error, handle| circuit_error_handler(error, handle) }

        state_before = circuit_state(light)
        result = light.run(&)
        emit_state_change_if_needed(name, light, state_before, cool_off)
        result
      rescue Stoplight::Error::RedLight
        raise AgentGenerationError, "Service unavailable (circuit open): #{name}"
      rescue StandardError => e
        emit_state_change_if_needed(name, light, state_before, cool_off)
        raise e
      end

      private

      # Custom error handler that skips non-circuit errors.
      def circuit_error_handler(error, handle)
        raise error if non_circuit_error?(error)

        handle.call(error)
      end

      # Check if an error should NOT trip the circuit.
      def non_circuit_error?(error)
        NON_CIRCUIT_ERRORS.any? { |klass| error.is_a?(klass) }
      end

      # Get the current circuit state as a symbol.
      # @param light [Stoplight::Light] The stoplight instance
      # @return [Symbol] :closed, :half_open, or :open
      def circuit_state(light)
        STOPLIGHT_TO_STATE.fetch(light.color, :closed)
      end

      # Emit a state change event if the circuit state has changed.
      # @param circuit_name [String] Name of the circuit
      # @param light [Stoplight::Light] The stoplight instance
      # @param from_state [Symbol] State before the operation
      # @param cool_off [Integer] Cool-off time in seconds
      def emit_state_change_if_needed(circuit_name, light, from_state, cool_off)
        to_state = circuit_state(light)
        return if from_state == to_state

        emit(Events::CircuitStateChanged.create(
               circuit_name:,
               from_state:,
               to_state:,
               error_count: circuit_error_count(light),
               cool_off_until: to_state == :open ? Time.now + cool_off : nil
             ))
      end

      # Get the current error count for a circuit.
      # @param light [Stoplight::Builder, Stoplight::Light] The stoplight instance
      # @return [Integer] Number of failures recorded
      def circuit_error_count(light)
        data_store = Stoplight.default_data_store
        built_light = light.respond_to?(:build) ? light.build : light
        data_store.get_failures(built_light).size
      end
    end
  end
end
