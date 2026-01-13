module Smolagents
  module Builders
    # Model type to class mapping
    MODEL_TYPES = {
      openai: "OpenAIModel",
      anthropic: "AnthropicModel",
      litellm: "LiteLLMModel",
      lm_studio: "OpenAIModel",
      ollama: "OpenAIModel",
      llama_cpp: "OpenAIModel",
      vllm: "OpenAIModel"
    }.freeze

    # Local server configurations
    LOCAL_SERVERS = {
      lm_studio: { port: 1234, host: "localhost" },
      ollama: { port: 11_434, host: "localhost" },
      llama_cpp: { port: 8080, host: "localhost" },
      vllm: { port: 8000, host: "localhost" }
    }.freeze

    # Fluent builder for composing model configurations with reliability features.
    #
    # ModelBuilder provides a chainable DSL for configuring models with
    # health checks, fallbacks, retry policies, request queueing, and monitoring callbacks.
    # Supports OpenAI-compatible APIs (LM Studio, Ollama, vLLM, etc.) and cloud providers
    # (OpenAI, Anthropic, LiteLLM).
    #
    # Built using Ruby 4.0 Data.define for immutability and pattern matching.
    #
    # @example Basic model with health checking
    #   model = Smolagents.model(:openai)
    #     .id("gpt-4")
    #     .api_key(ENV["OPENAI_API_KEY"])
    #     .with_health_check
    #     .build
    #
    # @example Local model with fallback
    #   model = Smolagents.model(:lm_studio)
    #     .id("local-model")
    #     .with_fallback { Smolagents.model(:ollama).id("llama3").build }
    #     .with_retry(max_attempts: 3)
    #     .build
    #
    # @example Full reliability stack
    #   model = Smolagents.model(:openai)
    #     .id("gpt-4")
    #     .api_key(ENV["OPENAI_API_KEY"])
    #     .temperature(0.7)
    #     .timeout(30)
    #     .with_health_check(cache_for: 10)
    #     .with_retry(max_attempts: 3, backoff: :exponential)
    #     .with_fallback { backup_model }
    #     .with_circuit_breaker(threshold: 5, reset_after: 60)
    #     .on_failover { |event| log("Failover: #{event.from_model} -> #{event.to_model}") }
    #     .on_error { |error, attempt, model| log("Attempt #{attempt} failed: #{error}") }
    #     .on_model_change { |old, new| log("Model changed: #{old} -> #{new}") }
    #     .build
    #
    # @example From existing model
    #   existing = OpenAIModel.new(model_id: "gpt-4", api_key: key)
    #   reliable = Smolagents.model(existing)
    #     .with_fallback { backup }
    #     .build
    #
    # @see Smolagents.model Factory method to create builders
    # @see Models::Model Base model interface
    # @see Concerns::ModelHealth Health check mixin
    # @see Concerns::ModelReliability Retry and fallback mixin
    ModelBuilder = Data.define(:type_or_model, :configuration) do
      include Base

      # Default configuration hash.
      #
      # Returns a hash containing default values for all model configuration options.
      # Used when creating a new builder to ensure all keys are initialized.
      #
      # @return [Hash] Default configuration with all keys set to nil or empty values:
      #   - callbacks: Monitoring event handlers
      #   - fallbacks: Backup models for failover
      #   - retry_policy: Automatic retry configuration
      #   - circuit_breaker: Request limiting on failures
      #   - health_check: Periodic health check configuration
      #
      # @api private
      def self.default_configuration
        {
          callbacks: [],
          fallbacks: [],
          retry_policy: nil,
          circuit_breaker: nil,
          health_check: nil
        }
      end

      # Factory method to create a new builder.
      #
      # Creates a ModelBuilder instance for the given model type or wraps
      # an existing model instance. For local servers (LM Studio, Ollama, etc.),
      # automatically configures the API endpoint and base path.
      #
      # @param type_or_model [Symbol, Model] Model type (:openai, :anthropic, :lm_studio, :ollama, etc.) or existing model instance. Default: :openai
      #
      # @return [ModelBuilder] New builder instance
      #
      # @example Creating a builder for OpenAI
      #   builder = ModelBuilder.create(:openai)
      #
      # @example Creating a builder for LM Studio (auto-configures localhost:1234)
      #   builder = ModelBuilder.create(:lm_studio)
      #
      # @example Wrapping an existing model
      #   model = OpenAIModel.new(model_id: "gpt-4", api_key: key)
      #   builder = ModelBuilder.create(model)
      #
      # @see Smolagents.model Recommended factory method
      def self.create(type_or_model = :openai)
        base_config = default_configuration

        if type_or_model.is_a?(Symbol)
          base_config = base_config.merge(type: type_or_model)

          if LOCAL_SERVERS.key?(type_or_model)
            server = LOCAL_SERVERS[type_or_model]
            base_config = base_config.merge(
              api_base: "http://#{server[:host]}:#{server[:port]}/v1",
              api_key: "not-needed"
            )
          end
        else
          # Wrap an existing model
          base_config = base_config.merge(existing_model: type_or_model)
        end

        new(type_or_model: type_or_model, configuration: base_config)
      end

      # Register builder methods for validation and help
      builder_method :id,
                     description: "Set the model identifier (e.g., 'gpt-4', 'claude-3-opus')",
                     required: true,
                     validates: ->(v) { v.is_a?(String) && !v.empty? }

      builder_method :temperature,
                     description: "Set temperature (0.0-2.0, default: 1.0)",
                     validates: ->(v) { v.is_a?(Numeric) && v >= 0.0 && v <= 2.0 },
                     aliases: [:temp]

      builder_method :max_tokens,
                     description: "Set maximum tokens in response (1-100000)",
                     validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 100_000 },
                     aliases: [:tokens]

      builder_method :timeout,
                     description: "Set request timeout in seconds (1-600)",
                     validates: ->(v) { v.is_a?(Numeric) && v.positive? && v <= 600 }

      builder_method :api_key,
                     description: "Set API authentication key",
                     validates: ->(v) { v.is_a?(String) && !v.empty? },
                     aliases: [:key]

      # Set the model ID.
      #
      # Sets the model identifier (e.g., "gpt-4", "claude-3-opus", "llama2").
      # This identifies which specific model version to use.
      #
      # @param model_id [String] The model identifier (required, non-empty)
      #
      # @return [ModelBuilder] New builder with model ID set
      #
      # @raise [ArgumentError] If model_id is empty
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting model ID
      #   builder.id("gpt-4")
      #   builder.id("claude-3-sonnet-20240229")
      #   builder.id("llama2-7b")
      #
      # @see Smolagents::Models::OpenAIModel For OpenAI model IDs
      # @see Smolagents::Models::AnthropicModel For Anthropic model IDs
      def id(model_id)
        check_frozen!
        validate!(:id, model_id)
        with_config(model_id: model_id)
      end

      # Set the API key.
      #
      # Sets the authentication key for API access. For local servers, this
      # can be a dummy value (e.g., "not-needed").
      #
      # @param key [String] API authentication key (required, non-empty)
      #
      # @return [ModelBuilder] New builder with API key set
      #
      # @raise [ArgumentError] If key is empty
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting API key
      #   builder.api_key(ENV["OPENAI_API_KEY"])
      #   builder.api_key("not-needed")  # For local servers
      #
      # @see #endpoint Set custom API base URL
      def api_key(key)
        check_frozen!
        validate!(:api_key, key)
        with_config(api_key: key)
      end

      # Set the API base URL.
      #
      # Sets the base URL for API calls. Useful for custom deployments,
      # local servers, or proxy setups.
      #
      # @param url [String] Base URL for API calls (e.g., "https://api.openai.com/v1")
      #
      # @return [ModelBuilder] New builder with endpoint set
      #
      # @example Setting custom endpoint
      #   builder.endpoint("http://localhost:1234/v1")
      #   builder.endpoint("https://api-custom.example.com/v1")
      #
      # @see #at Convenience method for host:port
      def endpoint(url)
        with_config(api_base: url)
      end

      # Set the temperature.
      #
      # Temperature controls randomness in responses (0.0 = deterministic,
      # higher = more creative). Range is 0.0 to 2.0.
      #
      # @param temp [Float] Temperature value (0.0-2.0)
      #
      # @return [ModelBuilder] New builder with temperature set
      #
      # @raise [ArgumentError] If temp is outside valid range
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting temperature
      #   builder.temperature(0.0)   # Deterministic responses
      #   builder.temperature(0.7)   # Balanced (common default)
      #   builder.temperature(1.5)   # Very creative
      #
      # @see #with_retry For controlling consistency via retries
      def temperature(temp)
        check_frozen!
        validate!(:temperature, temp)
        with_config(temperature: temp)
      end

      # Set the request timeout.
      #
      # Timeout in seconds for API requests. Prevents hanging on slow connections.
      #
      # @param seconds [Integer] Timeout in seconds (1-600, default: 30)
      #
      # @return [ModelBuilder] New builder with timeout set
      #
      # @raise [ArgumentError] If seconds is outside valid range
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting timeout
      #   builder.timeout(30)   # 30 second timeout
      #   builder.timeout(60)   # 1 minute timeout
      #
      # @see #with_retry Retry on timeout
      def timeout(seconds)
        check_frozen!
        validate!(:timeout, seconds)
        with_config(timeout: seconds)
      end

      # Set max tokens.
      #
      # Maximum number of tokens in the model response. Limits response length
      # and cost.
      #
      # @param tokens [Integer] Maximum tokens (1-100000)
      #
      # @return [ModelBuilder] New builder with max_tokens set
      #
      # @raise [ArgumentError] If tokens is outside valid range
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Setting max tokens
      #   builder.max_tokens(100)    # Short responses
      #   builder.max_tokens(2000)   # Long responses
      #
      # @see #temperature Control response quality
      def max_tokens(tokens)
        check_frozen!
        validate!(:max_tokens, tokens)
        with_config(max_tokens: tokens)
      end

      # Configure for a specific host/port (for local servers).
      #
      # Convenience method to set host and port for local model servers.
      # Automatically configures the correct API path for the model type
      # (e.g., /api/v1 for Ollama).
      #
      # @param host [String] Hostname (e.g., "localhost", "192.168.1.100")
      # @param port [Integer] Port number (e.g., 1234, 11434)
      #
      # @return [ModelBuilder] New builder with host/port configured
      #
      # @example Configuring LM Studio
      #   builder.at(host: "localhost", port: 1234)
      #
      # @example Configuring Ollama on remote machine
      #   builder.at(host: "192.168.1.100", port: 11434)
      #
      # @see #endpoint For custom API paths
      # @see LOCAL_SERVERS For default ports of local servers
      def at(host:, port:)
        type = configuration[:type]
        base_path = "/v1"
        base_path = "/api/v1" if type == :ollama
        with_config(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end

      # Enable health checking.
      #
      # Enables periodic health checks to verify the model is accessible.
      # Useful with fallbacks to route to healthy models.
      #
      # @param cache_for [Integer] Cache health check results for N seconds (default: 5)
      # @param **thresholds [Hash] Custom health check thresholds
      #
      # @return [ModelBuilder] New builder with health check enabled
      #
      # @example Enabling health checks
      #   builder.with_health_check
      #   builder.with_health_check(cache_for: 10)
      #
      # @see #with_fallback Pair with fallback for automatic recovery
      # @see #prefer_healthy Route to healthy models among fallbacks
      def with_health_check(cache_for: 5, **thresholds)
        with_config(health_check: { cache_for:, thresholds: })
      end

      # Configure retry behavior.
      #
      # Enables automatic retries on failure with configurable backoff strategy.
      # Helps handle transient failures and rate limiting.
      #
      # @param max_attempts [Integer] Maximum retry attempts (default: 3)
      # @param backoff [Symbol] Backoff strategy: :exponential, :linear, or :constant (default: :exponential)
      # @param base_interval [Float] Initial wait between retries in seconds (default: 1.0)
      # @param max_interval [Float] Maximum wait between retries in seconds (default: 30.0)
      #
      # @return [ModelBuilder] New builder with retry policy configured
      #
      # @example Basic retry
      #   builder.with_retry
      #
      # @example Custom retry with linear backoff
      #   builder.with_retry(max_attempts: 5, backoff: :linear, base_interval: 2.0, max_interval: 60.0)
      #
      # @see #with_fallback Fallback to different model on persistent failure
      # @see #with_circuit_breaker Prevent cascading failures
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        with_config(retry_policy: {
                      max_attempts:,
                      backoff:,
                      base_interval:,
                      max_interval:
                    })
      end

      # Add a fallback model.
      #
      # Specifies a backup model to use if the primary model fails. Multiple
      # fallbacks form a chain. Can use lazy instantiation with a block.
      #
      # @param model [Model, nil] Fallback model instance (optional)
      # @yield Block that returns a fallback model (lazy instantiation)
      #
      # @return [ModelBuilder] New builder with fallback added
      #
      # @example Fallback to another model
      #   primary = Smolagents.model(:openai).id("gpt-4").build
      #   backup = Smolagents.model(:openai).id("gpt-3.5-turbo").build
      #   reliable = Smolagents.model(primary).with_fallback(backup).build
      #
      # @example Lazy fallback instantiation
      #   builder.with_fallback { Smolagents.model(:ollama).id("llama2").build }
      #
      # @example Fallback chain
      #   model = Smolagents.model(:openai).id("gpt-4")
      #     .with_fallback(backup1)
      #     .with_fallback(backup2)
      #     .build
      #
      # @see #prefer_healthy Route to healthy fallbacks
      # @see #with_retry Retry before fallback
      def with_fallback(model = nil, &block)
        with_config(fallbacks: configuration[:fallbacks] + [model || block])
      end

      # Configure circuit breaker.
      #
      # Circuit breaker prevents cascading failures by stopping requests after
      # a threshold of failures is reached. Automatically attempts recovery after
      # a timeout period.
      #
      # @param threshold [Integer] Number of failures before opening circuit (default: 5)
      # @param reset_after [Integer] Seconds before attempting to recover (default: 60)
      #
      # @return [ModelBuilder] New builder with circuit breaker configured
      #
      # @example Circuit breaker
      #   builder.with_circuit_breaker(threshold: 3, reset_after: 30)
      #
      # @see #with_retry Retry individual requests
      # @see #with_fallback Failover to backup model
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        with_config(circuit_breaker: { threshold:, reset_after: })
      end

      # Enable request queueing for serial execution.
      #
      # Queues requests to ensure serial (one-at-a-time) execution.
      # Use this for servers with limited concurrency
      # (e.g., llama.cpp in single-batch mode, limited GPU memory).
      #
      # @param max_depth [Integer, nil] Maximum queue depth (nil = unlimited)
      #
      # @return [ModelBuilder] New builder with queue enabled
      #
      # @example Queueing for single-threaded server
      #   builder.with_queue
      #   builder.with_queue(max_depth: 100)
      #
      # @see #on_queue_wait Monitor queue wait times
      # @see Concerns::RequestQueue Implementation details
      def with_queue(max_depth: nil, **_ignored)
        with_config(queue: { max_depth: })
      end

      # Subscribe to request queue wait events.
      #
      # Registers a handler called while a request is waiting in the queue.
      # Useful for monitoring queue depth, implementing timeouts, or providing
      # progress updates to users.
      #
      # @yield [position, elapsed_seconds] Queue position and elapsed time
      # @yieldparam position [Integer] Current position in queue (0-indexed)
      # @yieldparam elapsed_seconds [Float] Seconds elapsed since request entered queue
      #
      # @return [ModelBuilder] New builder with callback registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Monitoring queue depth
      #   model = Smolagents.model(:lm_studio)
      #     .id("llama3")
      #     .with_queue
      #     .on_queue_wait { |pos, elapsed| puts "Position: #{pos}, waited: #{elapsed}s" }
      #     .build
      #
      # @example User-facing queue notification
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_queue(max_depth: 100)
      #     .on_queue_wait do |position, elapsed|
      #       notify_user("Queued: #{position + 1} ahead, #{elapsed.round}s waiting")
      #     end
      #     .build
      #
      # @see #on Generic callback registration
      # @see #with_queue Enable request queueing
      # @see Concerns::RequestQueue Queue implementation
      def on_queue_wait(&) = on(:queue_wait, &)

      # Prefer healthy models when using fallbacks.
      #
      # When multiple fallbacks are available, this will prefer models
      # that have passed recent health checks over those that haven't.
      #
      # @return [ModelBuilder] New builder with prefer_healthy enabled
      #
      # @example Preferring healthy models
      #   builder
      #     .with_health_check
      #     .with_fallback(backup1)
      #     .with_fallback(backup2)
      #     .prefer_healthy
      #     .build
      #
      # @see #with_health_check Enable health checking
      # @see #with_fallback Add fallback models
      def prefer_healthy
        with_config(prefer_healthy: true)
      end

      # Register a callback for an event.
      #
      # This is the generic callback method. Specific methods like {#on_failover},
      # {#on_error}, etc. are provided for convenience.
      #
      # @param event [Symbol] Event type (:failover, :error, :recovery, :model_change, :queue_wait)
      # @yield Block to call when event occurs
      #
      # @return [ModelBuilder] New builder with callback added
      #
      # @example Generic callback
      #   builder.on(:failover) { |event| log("Failover occurred") }
      #
      # @see #on_failover Convenience for failover events
      # @see #on_error Convenience for error events
      # @see #on_recovery Convenience for recovery events
      # @see #on_model_change Convenience for model change events
      def on(event, &block)
        with_config(callbacks: configuration[:callbacks] + [{ type: event, handler: block }])
      end

      # Subscribe to model failover events.
      #
      # Registers a handler called when the model switches to a fallback model
      # due to failure. Useful for alerting on fallback activation, logging
      # degraded service status, or implementing fallback-specific behaviors.
      #
      # @yield [event] Failover event
      # @yieldparam event [Object] Event object with from_model and to_model details
      #
      # @return [ModelBuilder] New builder with callback registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Alerting on failover
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_fallback { backup_model }
      #     .on_failover { |event| alert("Failover: #{event.from_model} -> #{event.to_model}") }
      #     .build
      #
      # @example Logging degraded service
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_fallback(backup)
      #     .on_failover { |e| logger.warn("Primary model failed, using fallback") }
      #     .build
      #
      # @see #on Generic callback registration
      # @see #with_fallback Add fallback models
      # @see #on_model_change Detect any model change
      def on_failover(&) = on(:failover, &)

      # Subscribe to error events.
      #
      # Registers a handler called when a request fails (before retries or fallbacks
      # are attempted). Useful for implementing custom error handling, metrics,
      # or logging failure details.
      #
      # @yield [error, attempt, model] Error details and attempt number
      # @yieldparam error [Exception] The error that occurred
      # @yieldparam attempt [Integer] Current attempt number (1-indexed)
      # @yieldparam model [Model] The model that failed
      #
      # @return [ModelBuilder] New builder with callback registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Logging errors
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_retry(max_attempts: 3)
      #     .on_error { |err, attempt, m| logger.error("Attempt #{attempt} failed", err) }
      #     .build
      #
      # @example Custom error handling
      #   model = Smolagents.model(:lm_studio)
      #     .id("llama3")
      #     .with_retry
      #     .on_error do |error, attempt, _model|
      #       log_metric("model_error", tags: { attempt: attempt, error_type: error.class.name })
      #     end
      #     .build
      #
      # @see #on Generic callback registration
      # @see #with_retry Configure retry behavior
      # @see #with_fallback Set up fallback models
      def on_error(&) = on(:error, &)

      # Subscribe to model recovery events.
      #
      # Registers a handler called when a failed model recovers successfully
      # (e.g., after retry succeeds, or circuit breaker resets). Useful for
      # cleanup, notifying about recovery, or adjusting request patterns.
      #
      # @yield [model, attempt] Model ID and attempt number
      # @yieldparam model [String] The model ID that recovered
      # @yieldparam attempt [Integer] The attempt number that succeeded
      #
      # @return [ModelBuilder] New builder with callback registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Notifying on recovery
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_retry
      #     .with_circuit_breaker
      #     .on_recovery { |m, attempt| logger.info("Model recovered at attempt #{attempt}") }
      #     .build
      #
      # @example Clearing error counters
      #   model = Smolagents.model(:lm_studio)
      #     .id("llama3")
      #     .with_retry(max_attempts: 5)
      #     .on_recovery { |_model, _attempt| reset_error_metrics }
      #     .build
      #
      # @see #on Generic callback registration
      # @see #with_circuit_breaker Configure failure tracking
      # @see #with_retry Configure retry behavior
      def on_recovery(&) = on(:recovery, &)

      # Subscribe to model change events.
      #
      # Registers a handler called whenever the active model changes (failover,
      # recovery, or explicit switches). Useful for tracking which models are
      # being used, alerting on unexpected changes, or updating UI.
      #
      # @yield [old_model_id, new_model_id] Model IDs before and after change
      # @yieldparam old_model_id [String] The previous model ID
      # @yieldparam new_model_id [String] The new model ID
      #
      # @return [ModelBuilder] New builder with callback registered
      #
      # @raise [FrozenError] If builder configuration is frozen
      #
      # @example Tracking model usage
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_fallback(backup)
      #     .on_model_change { |old, new| analytics.log_model_switch(old, new) }
      #     .build
      #
      # @example Updating UI on model change
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .with_fallback(gpt_35_turbo)
      #     .on_model_change { |old, new| ui.set_status("Using: #{new}") }
      #     .build
      #
      # @see #on Generic callback registration
      # @see #on_failover Detect failover specifically
      # @see #on_recovery Detect recovery specifically
      def on_model_change(&) = on(:model_change, &)

      # Build the configured model.
      #
      # Creates and configures a Model instance with all reliability features
      # (health checks, retries, fallbacks, etc.). The model is wrapped with
      # appropriate mixins based on configuration.
      #
      # @return [Model] Configured model instance with reliability features
      #
      # @example Building a reliable model
      #   model = Smolagents.model(:openai)
      #     .id("gpt-4")
      #     .api_key(ENV["OPENAI_API_KEY"])
      #     .with_retry(max_attempts: 3)
      #     .with_fallback(backup_model)
      #     .with_health_check
      #     .build
      #   response = model.generate("Hello")
      #
      # @see ModelBuilder Factory method to start building
      # @see Concerns::ModelHealth Health check mixin
      # @see Concerns::ModelReliability Retry and fallback mixin
      # @see Concerns::RequestQueue Request queueing mixin
      def build
        model = create_base_model
        apply_health_check(model)
        apply_queue(model)
        apply_reliability(model)
        apply_callbacks(model)
        model
      end

      # Get current configuration (for inspection)
      #
      # @return [Hash] Current configuration
      def config
        configuration.dup
      end

      # Pretty print configuration
      def inspect
        parts = ["#<ModelBuilder"]
        parts << "type=#{configuration[:type]}" if configuration[:type]
        parts << "model_id=#{configuration[:model_id]}" if configuration[:model_id]
        parts << "fallbacks=#{configuration[:fallbacks].size}" if configuration[:fallbacks].any?
        parts << "health_check" if configuration[:health_check]
        parts << "retry=#{configuration[:retry_policy][:max_attempts]}" if configuration[:retry_policy]
        "#{parts.join(" ")}>"
      end

      private

      # Immutable update helper - creates new builder with merged config
      #
      # @param kwargs [Hash] Configuration changes
      # @return [ModelBuilder] New builder instance
      def with_config(**kwargs)
        self.class.new(type_or_model: type_or_model, configuration: configuration.merge(kwargs))
      end

      def create_base_model
        return configuration[:existing_model] if configuration[:existing_model]

        type = configuration[:type] || :openai
        class_name = MODEL_TYPES[type] || MODEL_TYPES[:openai]
        model_class = Smolagents.const_get(class_name)

        model_args = {
          model_id: configuration[:model_id] || "default",
          api_key: configuration[:api_key],
          api_base: configuration[:api_base],
          temperature: configuration[:temperature],
          max_tokens: configuration[:max_tokens],
          timeout: configuration[:timeout]
        }.compact

        model_class.new(**model_args)
      end

      def apply_health_check(model)
        return unless configuration[:health_check]

        # Extend with ModelHealth if not already included
        return if model.singleton_class.include?(Concerns::ModelHealth)

        model.extend(Concerns::ModelHealth)
      end

      def apply_queue(model)
        return unless configuration[:queue]

        # Extend with RequestQueue
        model.extend(Concerns::RequestQueue) unless model.singleton_class.include?(Concerns::RequestQueue)

        model.enable_queue(**configuration[:queue].compact)
      end

      def apply_reliability(model)
        has_reliability = configuration[:retry_policy] || configuration[:fallbacks].any? || configuration[:prefer_healthy]
        return unless has_reliability

        # Extend with ModelReliability
        unless model.singleton_class.include?(Concerns::ModelReliability)
          # Save original generate method
          original = model.method(:generate)
          model.define_singleton_method(:original_generate) { |*args, **kwargs| original.call(*args, **kwargs) }
          model.extend(Concerns::ModelReliability)
        end

        # Apply retry policy
        model.with_retry(**configuration[:retry_policy]) if configuration[:retry_policy]

        # Apply fallbacks
        configuration[:fallbacks].each do |fallback|
          fb_model = fallback.is_a?(Proc) ? fallback.call : fallback
          model.with_fallback(fb_model)
        end

        # Apply prefer_healthy
        return unless configuration[:prefer_healthy]

        cache = configuration.dig(:health_check, :cache_for) || 5
        model.prefer_healthy(cache_health_for: cache)
      end

      def apply_callbacks(model)
        configuration[:callbacks].each do |callback|
          method_name = :"on_#{callback[:type]}"
          model.public_send(method_name, &callback[:handler]) if model.respond_to?(method_name)
        end
      end
    end
  end
end
