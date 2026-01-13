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
    # health checks, fallbacks, retry policies, and monitoring callbacks.
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
    ModelBuilder = Data.define(:type_or_model, :configuration) do
      include Base

      # Default configuration hash
      #
      # @return [Hash] Default configuration
      def self.default_configuration
        {
          callbacks: [],
          fallbacks: [],
          retry_policy: nil,
          circuit_breaker: nil,
          health_check: nil
        }
      end

      # Factory method to create a new builder (maintains backwards compatibility)
      #
      # @param type_or_model [Symbol, Model] Model type or existing model instance
      # @return [ModelBuilder] New builder instance
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

      # Set the model ID
      #
      # @param model_id [String] The model identifier
      # @return [ModelBuilder] New builder with model ID set
      def id(model_id)
        check_frozen!
        validate!(:id, model_id)
        with_config(model_id: model_id)
      end

      # Set the API key
      #
      # @param key [String] API key
      # @return [ModelBuilder] New builder with API key set
      def api_key(key)
        check_frozen!
        validate!(:api_key, key)
        with_config(api_key: key)
      end

      # Set the API base URL
      #
      # @param url [String] Base URL for API calls
      # @return [ModelBuilder] New builder with endpoint set
      def endpoint(url)
        with_config(api_base: url)
      end

      # Set the temperature
      #
      # @param temp [Float] Temperature (0.0-2.0)
      # @return [ModelBuilder] New builder with temperature set
      def temperature(temp)
        check_frozen!
        validate!(:temperature, temp)
        with_config(temperature: temp)
      end

      # Set the request timeout
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [ModelBuilder] New builder with timeout set
      def timeout(seconds)
        check_frozen!
        validate!(:timeout, seconds)
        with_config(timeout: seconds)
      end

      # Set max tokens
      #
      # @param tokens [Integer] Maximum tokens in response
      # @return [ModelBuilder] New builder with max_tokens set
      def max_tokens(tokens)
        check_frozen!
        validate!(:max_tokens, tokens)
        with_config(max_tokens: tokens)
      end

      # Configure for a specific host/port (for local servers)
      #
      # @param host [String] Hostname
      # @param port [Integer] Port number
      # @return [ModelBuilder] New builder with host/port configured
      def at(host:, port:)
        type = configuration[:type]
        base_path = "/v1"
        base_path = "/api/v1" if type == :ollama
        with_config(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end

      # Enable health checking
      #
      # @param cache_for [Integer] Cache health check results for N seconds
      # @param thresholds [Hash] Custom health thresholds
      # @return [ModelBuilder] New builder with health check enabled
      def with_health_check(cache_for: 5, **thresholds)
        with_config(health_check: { cache_for:, thresholds: })
      end

      # Configure retry behavior
      #
      # @param max_attempts [Integer] Maximum retry attempts
      # @param backoff [Symbol] Backoff strategy (:exponential, :linear, :constant)
      # @param base_interval [Float] Initial wait between retries
      # @param max_interval [Float] Maximum wait between retries
      # @return [ModelBuilder] New builder with retry policy configured
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        with_config(retry_policy: {
                      max_attempts:,
                      backoff:,
                      base_interval:,
                      max_interval:
                    })
      end

      # Add a fallback model
      #
      # @param model [Model, nil] Fallback model instance
      # @yield Block that returns a fallback model (lazy instantiation)
      # @return [ModelBuilder] New builder with fallback added
      def with_fallback(model = nil, &block)
        with_config(fallbacks: configuration[:fallbacks] + [model || block])
      end

      # Configure circuit breaker
      #
      # @param threshold [Integer] Number of failures before opening circuit
      # @param reset_after [Integer] Seconds before trying again
      # @return [ModelBuilder] New builder with circuit breaker configured
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        with_config(circuit_breaker: { threshold:, reset_after: })
      end

      # Enable request queueing for serial execution
      #
      # Use this for servers that can only handle one request at a time
      # (e.g., llama.cpp in single-batch mode, limited GPU memory).
      #
      # @param max_depth [Integer, nil] Maximum queue depth
      # @return [ModelBuilder] New builder with queue enabled
      def with_queue(max_depth: nil, **_ignored)
        with_config(queue: { max_depth: })
      end

      # @!method on_queue_wait(&block)
      #   Register queue wait callback
      #   @yield [position, elapsed_seconds] Called while waiting in queue
      #   @return [ModelBuilder] New builder with callback added
      def on_queue_wait(&) = on(:queue_wait, &)

      # Prefer healthy models when using fallbacks
      #
      # @return [ModelBuilder] New builder with prefer_healthy enabled
      def prefer_healthy
        with_config(prefer_healthy: true)
      end

      # Register a callback for an event.
      #
      # This is the generic callback method. Specific methods like on_failover,
      # on_error, etc. are provided for convenience.
      #
      # @param event [Symbol] Event type (:failover, :error, :recovery, :model_change, :queue_wait)
      # @yield Block to call when event occurs
      # @return [ModelBuilder] New builder with callback added
      def on(event, &block)
        with_config(callbacks: configuration[:callbacks] + [{ type: event, handler: block }])
      end

      # @!method on_failover(&block)
      #   Register failover callback
      #   @yield [FailoverEvent] Called when failover occurs
      #   @return [ModelBuilder] New builder with callback added
      def on_failover(&) = on(:failover, &)

      # @!method on_error(&block)
      #   Register error callback
      #   @yield [error, attempt, model] Called on each error
      #   @return [ModelBuilder] New builder with callback added
      def on_error(&) = on(:error, &)

      # @!method on_recovery(&block)
      #   Register recovery callback
      #   @yield [model, attempt] Called on successful recovery
      #   @return [ModelBuilder] New builder with callback added
      def on_recovery(&) = on(:recovery, &)

      # @!method on_model_change(&block)
      #   Register model change callback
      #   @yield [old_model_id, new_model_id] Called when model changes
      #   @return [ModelBuilder] New builder with callback added
      def on_model_change(&) = on(:model_change, &)

      # Build the configured model
      #
      # @return [Model] Configured model instance
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
