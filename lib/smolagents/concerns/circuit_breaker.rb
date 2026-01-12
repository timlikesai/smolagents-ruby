require "stoplight"

module Smolagents
  module Concerns
    module CircuitBreaker
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
