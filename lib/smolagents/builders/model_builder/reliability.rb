module Smolagents
  module Builders
    module ModelBuilderReliability
      # Reliability configuration methods for ModelBuilder.
      #
      # Provides chainable methods for configuring health checks, retries,
      # fallbacks, circuit breakers, and request queueing.
      #
      # @example Full reliability configuration
      #   Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_health_check
      #     .with_retry(max_attempts: 3)
      #     .with_circuit_breaker(threshold: 5)
      #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
      #     .prefer_healthy
      #     .build

      # Enable health checking.
      #
      # @param cache_for [Integer] Cache results for N seconds (default: 5)
      # @param thresholds [Hash] Custom health check thresholds
      # @return [ModelBuilder] New builder with health check enabled
      # @example Basic health check
      #   .with_health_check
      # @example Custom cache duration
      #   .with_health_check(cache_for: 30)
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
      # @example Basic retry
      #   .with_retry
      # @example Custom retry policy
      #   .with_retry(max_attempts: 5, backoff: :linear, base_interval: 2.0)
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        with_config(retry_policy: { max_attempts:, backoff:, base_interval:, max_interval: })
      end

      # Add a fallback model.
      #
      # Blocks are preferred for **lazy instantiation** - the fallback model
      # isn't created unless the primary fails. This avoids wasting resources
      # on backup models that may never be needed.
      #
      # @param model [Model, nil] Fallback model instance (eager, created immediately)
      # @yield Block returning fallback model (lazy, created only if needed)
      # @return [ModelBuilder] New builder with fallback added
      # @example With block (recommended - model created only if primary fails)
      #   .with_fallback { Smolagents.model(:ollama).id("llama3").build }
      # @example With instance (model created immediately, even if never used)
      #   fallback = OpenAIModel.ollama("llama3")
      #   .with_fallback(fallback)
      # @example Chain multiple fallbacks (tried in order)
      #   .with_fallback { OpenAIModel.ollama("llama3") }
      #   .with_fallback { AnthropicModel.new(model_id: "claude-3-haiku") }
      def with_fallback(model = nil, &block)
        with_config(fallbacks: configuration[:fallbacks] + [model || block])
      end

      # Configure circuit breaker.
      #
      # @param threshold [Integer] Failures before opening (default: 5)
      # @param reset_after [Integer] Seconds before recovery attempt (default: 60)
      # @return [ModelBuilder] New builder with circuit breaker
      # @example Default circuit breaker
      #   .with_circuit_breaker
      # @example Custom thresholds
      #   .with_circuit_breaker(threshold: 3, reset_after: 30)
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        with_config(circuit_breaker: { threshold:, reset_after: })
      end

      # Enable request queueing for serial execution.
      #
      # @param max_depth [Integer, nil] Maximum queue depth (nil = unlimited)
      # @return [ModelBuilder] New builder with queue enabled
      # @example Unlimited queue
      #   .with_queue
      # @example Limited queue depth
      #   .with_queue(max_depth: 100)
      def with_queue(max_depth: nil, **_ignored)
        with_config(queue: { max_depth: })
      end

      # Prefer healthy models when using fallbacks.
      #
      # When enabled, the model will route requests to healthy fallbacks
      # first rather than always trying the primary model.
      #
      # @return [ModelBuilder] New builder with prefer_healthy enabled
      # @example Route to healthy models first
      #   .with_health_check
      #   .with_fallback { backup_model }
      #   .prefer_healthy
      def prefer_healthy
        with_config(prefer_healthy: true)
      end
    end
  end
end
