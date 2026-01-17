module Smolagents
  module Builders
    # Reliability configuration methods for ModelBuilder.
    #
    # Provides chainable methods for configuring health checks, retries,
    # fallbacks, circuit breakers, and request queueing. Each method returns
    # a new builder instance for immutable chaining.
    #
    # @see ModelBuilder The main builder class
    module ModelBuilderReliability
      # Enable health checking for the model.
      #
      # Health checks monitor model availability and can be used with
      # +prefer_healthy+ to route requests to healthy models first.
      #
      # @param cache_for [Integer] Cache health check results for N seconds (default: 5)
      # @param thresholds [Hash] Custom health check thresholds
      # @return [ModelBuilder] New builder with health check enabled
      #
      # @example Enable health check with defaults
      #   builder = Smolagents.model(:openai).id("gpt-4").with_health_check
      #   builder.config[:health_check].nil?
      #   #=> false
      #
      # @example Custom cache duration
      #   builder = Smolagents.model(:openai).id("gpt-4").with_health_check(cache_for: 30)
      #   builder.config[:health_check][:cache_for]
      #   #=> 30
      def with_health_check(cache_for: 5, **thresholds)
        with_config(health_check: { cache_for:, thresholds: })
      end

      # Configure automatic retry behavior for transient failures.
      #
      # Retries are useful for handling temporary network issues or API rate limits.
      # Supports multiple backoff strategies.
      #
      # @param max_attempts [Integer] Maximum retry attempts (default: 3)
      # @param backoff [Symbol] Strategy: :exponential, :linear, :constant
      # @param base_interval [Float] Initial wait in seconds (default: 1.0)
      # @param max_interval [Float] Maximum wait in seconds (default: 30.0)
      # @return [ModelBuilder] New builder with retry policy configured
      #
      # @example Enable retry with defaults
      #   builder = Smolagents.model(:openai).id("gpt-4").with_retry
      #   builder.config[:retry_policy][:max_attempts]
      #   #=> 3
      #
      # @example Custom retry policy
      #   builder = Smolagents.model(:openai).id("gpt-4").with_retry(max_attempts: 5, backoff: :linear)
      #   builder.config[:retry_policy][:backoff]
      #   #=> :linear
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        with_config(retry_policy: { max_attempts:, backoff:, base_interval:, max_interval: })
      end

      # Add a fallback model for automatic failover.
      #
      # When the primary model fails, the fallback model is used automatically.
      # Blocks are preferred for **lazy instantiation** - the fallback model
      # isn't created unless the primary fails. This avoids wasting resources
      # on backup models that may never be needed.
      #
      # Multiple fallbacks can be chained and are tried in order.
      #
      # @param model [Model, nil] Fallback model instance (eager, created immediately)
      # @yield Block returning fallback model (lazy, created only if needed)
      # @return [ModelBuilder] New builder with fallback added
      #
      # @example Adding a fallback with block (lazy)
      #   builder = Smolagents.model(:openai).id("gpt-4")
      #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
      #   builder.config[:fallbacks].size
      #   #=> 1
      #
      # @example Adding a fallback with instance (eager)
      #   fallback = Smolagents::OpenAIModel.new(model_id: "gpt-3.5-turbo")
      #   builder = Smolagents.model(:openai).id("gpt-4").with_fallback(fallback)
      #   builder.config[:fallbacks].size
      #   #=> 1
      def with_fallback(model = nil, &block)
        with_config(fallbacks: configuration[:fallbacks] + [model || block])
      end

      # Configure circuit breaker to prevent cascade failures.
      #
      # The circuit breaker opens after a threshold of consecutive failures,
      # preventing further requests until a recovery period has passed.
      # This protects your application from overwhelming a failing service.
      #
      # @param threshold [Integer] Failures before opening circuit (default: 5)
      # @param reset_after [Integer] Seconds before recovery attempt (default: 60)
      # @return [ModelBuilder] New builder with circuit breaker configured
      #
      # @example Enable circuit breaker with defaults
      #   builder = Smolagents.model(:openai).id("gpt-4").with_circuit_breaker
      #   builder.config[:circuit_breaker][:threshold]
      #   #=> 5
      #
      # @example Custom thresholds
      #   builder = Smolagents.model(:openai).id("gpt-4").with_circuit_breaker(threshold: 3, reset_after: 30)
      #   builder.config[:circuit_breaker][:reset_after]
      #   #=> 30
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        with_config(circuit_breaker: { threshold:, reset_after: })
      end

      # Enable request queueing for serial execution.
      #
      # Queueing ensures requests are processed one at a time, which can be
      # useful for rate-limited APIs or resource-constrained environments.
      #
      # @param max_depth [Integer, nil] Maximum queue depth (nil = unlimited)
      # @return [ModelBuilder] New builder with queue enabled
      #
      # @example Enable queueing with unlimited depth
      #   builder = Smolagents.model(:openai).id("gpt-4").with_queue
      #   builder.config[:queue].key?(:max_depth)
      #   #=> true
      #
      # @example Limited queue depth
      #   builder = Smolagents.model(:openai).id("gpt-4").with_queue(max_depth: 100)
      #   builder.config[:queue][:max_depth]
      #   #=> 100
      def with_queue(max_depth: nil, **_ignored)
        with_config(queue: { max_depth: })
      end

      # Prefer healthy models when using fallbacks.
      #
      # When enabled with health checks and fallbacks, requests are routed
      # to healthy models first rather than always trying the primary model.
      # This improves reliability when the primary model is experiencing issues.
      #
      # @return [ModelBuilder] New builder with prefer_healthy enabled
      #
      # @example Enable healthy model preference
      #   builder = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_health_check
      #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
      #     .prefer_healthy
      #   builder.config[:prefer_healthy]
      #   #=> true
      def prefer_healthy
        with_config(prefer_healthy: true)
      end
    end
  end
end
