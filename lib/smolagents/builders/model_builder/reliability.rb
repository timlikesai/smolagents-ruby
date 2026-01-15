module Smolagents
  module Builders
    module ModelBuilderReliability
      # Reliability configuration methods for ModelBuilder.
      #
      # Provides chainable methods for configuring health checks, retries,
      # fallbacks, circuit breakers, and request queueing.

      # Enable health checking.
      #
      # @param cache_for [Integer] Cache results for N seconds (default: 5)
      # @param thresholds [Hash] Custom health check thresholds
      # @return [ModelBuilder] New builder with health check enabled
      def with_health_check(cache_for: 5, **thresholds)
        with_config(health_check: { cache_for:, thresholds: })
      end

      # Configure retry behavior.
      #
      # @param max_attempts [Integer] Maximum retry attempts (default: 3)
      # @param backoff [Symbol] Strategy: :exponential, :linear, :constant
      # @param base_interval [Float] Initial wait in seconds (default: 1.0)
      # @param max_interval [Float] Maximum wait in seconds (default: 30.0)
      # @return [ModelBuilder] New builder with retry policy
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        with_config(retry_policy: { max_attempts:, backoff:, base_interval:, max_interval: })
      end

      # Add a fallback model.
      #
      # @param model [Model, nil] Fallback model instance
      # @yield Block returning fallback model (lazy instantiation)
      # @return [ModelBuilder] New builder with fallback added
      def with_fallback(model = nil, &block)
        with_config(fallbacks: configuration[:fallbacks] + [model || block])
      end

      # Configure circuit breaker.
      #
      # @param threshold [Integer] Failures before opening (default: 5)
      # @param reset_after [Integer] Seconds before recovery attempt (default: 60)
      # @return [ModelBuilder] New builder with circuit breaker
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        with_config(circuit_breaker: { threshold:, reset_after: })
      end

      # Enable request queueing for serial execution.
      #
      # @param max_depth [Integer, nil] Maximum queue depth (nil = unlimited)
      # @return [ModelBuilder] New builder with queue enabled
      def with_queue(max_depth: nil, **_ignored)
        with_config(queue: { max_depth: })
      end

      # Prefer healthy models when using fallbacks.
      #
      # @return [ModelBuilder] New builder with prefer_healthy enabled
      def prefer_healthy
        with_config(prefer_healthy: true)
      end
    end
  end
end
