require_relative "resilience/retry_policy"
require_relative "resilience/retryable"
require_relative "resilience/tool_retry"
require_relative "resilience/circuit_breaker"
require_relative "resilience/rate_limiter"
require_relative "resilience/events"
require_relative "resilience/fallback"
require_relative "resilience/health_routing"
require_relative "resilience/retry_execution"
require_relative "resilience/notifications"

module Smolagents
  module Concerns
    # Unified resilience concern composing rate limiting and circuit breaking.
    #
    # This concern provides a single include for tools that need both
    # rate limiting (to respect API limits) and circuit breaking (to
    # fail fast when services are down).
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern          | Depends On             | Depended By       | Auto-Includes |
    #   |------------------|------------------------|-------------------|---------------|
    #   | RetryPolicy      | -                      | Retryable,        | -             |
    #   |                  |                        | ModelReliability  |               |
    #   | Retryable        | RetryPolicy            | ToolRetry         | -             |
    #   | ToolRetry        | Retryable              | -                 | -             |
    #   | CircuitBreaker   | -                      | Resilience        | -             |
    #   | RateLimiter      | -                      | Resilience        | -             |
    #   | Resilience       | CircuitBreaker,        | -                 | CircuitBreaker|
    #   |                  | RateLimiter            |                   | RateLimiter   |
    #   | Events           | -                      | ModelReliability  | -             |
    #   | ModelFallback    | -                      | ModelReliability  | -             |
    #   | HealthRouting    | ModelHealth (optional) | ModelReliability  | -             |
    #   | RetryExecution   | RetryPolicy            | ModelReliability  | -             |
    #   | Notifications    | Events::Emitter        | ModelReliability  | -             |
    #
    # == Sub-concern Methods
    #
    #   RetryPolicy
    #       +-- build_policy(**opts) - Factory for RetryPolicy instances
    #       +-- delay_for_attempt(n) - Calculate exponential backoff delay
    #       +-- should_retry?(error) - Check if error is retryable
    #
    #   Retryable
    #       +-- with_retry(**opts, &block) - Execute block with retry logic
    #       +-- retryable_errors - List of errors that trigger retry
    #
    #   ToolRetry
    #       +-- retry_tool_execution(tool, **) - Retry tool with backoff
    #       +-- tool_retry_policy - Get configured retry policy
    #
    #   CircuitBreaker
    #       +-- with_circuit_breaker(name, **) - Wrap call in circuit
    #       +-- circuit_open?(name) - Check if circuit is tripped
    #       +-- reset_circuit(name) - Manually reset circuit
    #
    #   RateLimiter
    #       +-- enforce_rate_limit! - Block until rate limit allows
    #       +-- rate_limit_available? - Check if request allowed
    #       +-- rate_limit(rate) - Class method to set rate
    #
    #   Resilience (composite)
    #       +-- resilient_call(name, **) - Combined rate limit + circuit
    #
    # == Instance Variables Set
    #
    # *CircuitBreaker*:
    # - @circuits [Hash] - Map of circuit name to CircuitState
    #
    # *RateLimiter*:
    # - @last_request_at [Float] - Timestamp of last request
    # - @rate_limit_seconds [Float] - Minimum seconds between requests
    #
    # == Class-Level Configuration
    #
    # *RateLimiter*:
    # - rate_limit(seconds) - Set rate limit for all instances
    #
    # == Thread Safety
    #
    # CircuitBreaker: Thread-safe via Mutex in CircuitState
    # RateLimiter: Thread-safe via sleep-based throttling
    #
    # @!endgroup
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
    # @see ToolRetry For tool-specific retry logic
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
