module Smolagents
  module Builders
    # Fluent builder for composing model configurations with reliability features.
    #
    # ModelBuilder provides a chainable DSL for configuring models with
    # health checks, fallbacks, retry policies, and monitoring callbacks.
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
    class ModelBuilder
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

      def initialize(type_or_model = :openai)
        @config = {
          callbacks: [],
          fallbacks: [],
          retry_policy: nil,
          circuit_breaker: nil,
          health_check: nil
        }

        if type_or_model.is_a?(Symbol)
          @config[:type] = type_or_model
          configure_local_server(type_or_model) if LOCAL_SERVERS.key?(type_or_model)
        else
          # Wrap an existing model
          @config[:existing_model] = type_or_model
        end
      end

      # Set the model ID
      #
      # @param model_id [String] The model identifier
      # @return [ModelBuilder] self for chaining
      def id(model_id)
        with(model_id:)
      end

      # Set the API key
      #
      # @param key [String] API key
      # @return [ModelBuilder] self for chaining
      def api_key(key)
        with(api_key: key)
      end

      # Set the API base URL
      #
      # @param url [String] Base URL for API calls
      # @return [ModelBuilder] self for chaining
      def endpoint(url)
        with(api_base: url)
      end
      alias api_base endpoint

      # Set the temperature
      #
      # @param temp [Float] Temperature (0.0-2.0)
      # @return [ModelBuilder] self for chaining
      def temperature(temp)
        with(temperature: temp)
      end

      # Set the request timeout
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [ModelBuilder] self for chaining
      def timeout(seconds)
        with(timeout: seconds)
      end

      # Set max tokens
      #
      # @param tokens [Integer] Maximum tokens in response
      # @return [ModelBuilder] self for chaining
      def max_tokens(tokens)
        with(max_tokens: tokens)
      end

      # Configure for a specific host/port (for local servers)
      #
      # @param host [String] Hostname
      # @param port [Integer] Port number
      # @return [ModelBuilder] self for chaining
      def at(host:, port:)
        type = @config[:type]
        base_path = "/v1"
        base_path = "/api/v1" if type == :ollama
        with(api_base: "http://#{host}:#{port}#{base_path}", api_key: "not-needed")
      end

      # Enable health checking
      #
      # @param cache_for [Integer] Cache health check results for N seconds
      # @param thresholds [Hash] Custom health thresholds
      # @return [ModelBuilder] self for chaining
      def with_health_check(cache_for: 5, **thresholds)
        @config[:health_check] = { cache_for:, thresholds: }
        self
      end

      # Configure retry behavior
      #
      # @param max_attempts [Integer] Maximum retry attempts
      # @param backoff [Symbol] Backoff strategy (:exponential, :linear, :constant)
      # @param base_interval [Float] Initial wait between retries
      # @param max_interval [Float] Maximum wait between retries
      # @return [ModelBuilder] self for chaining
      def with_retry(max_attempts: 3, backoff: :exponential, base_interval: 1.0, max_interval: 30.0)
        @config[:retry_policy] = {
          max_attempts:,
          backoff:,
          base_interval:,
          max_interval:
        }
        self
      end

      # Add a fallback model
      #
      # @param model [Model, nil] Fallback model instance
      # @yield Block that returns a fallback model (lazy instantiation)
      # @return [ModelBuilder] self for chaining
      def with_fallback(model = nil, &block)
        @config[:fallbacks] << (model || block)
        self
      end

      # Configure circuit breaker
      #
      # @param threshold [Integer] Number of failures before opening circuit
      # @param reset_after [Integer] Seconds before trying again
      # @return [ModelBuilder] self for chaining
      def with_circuit_breaker(threshold: 5, reset_after: 60)
        @config[:circuit_breaker] = { threshold:, reset_after: }
        self
      end

      # Enable request queueing for serial execution
      #
      # Use this for servers that can only handle one request at a time
      # (e.g., llama.cpp in single-batch mode, limited GPU memory).
      #
      # @param timeout [Integer, nil] Max seconds to wait in queue
      # @param max_depth [Integer, nil] Maximum queue depth
      # @return [ModelBuilder] self for chaining
      def with_queue(timeout: nil, max_depth: nil)
        @config[:queue] = { timeout:, max_depth: }
        self
      end
      alias serialized with_queue

      # Register queue wait callback
      #
      # @yield [position, elapsed_seconds] Called while waiting in queue
      # @return [ModelBuilder] self for chaining
      def on_queue_wait(&block)
        @config[:callbacks] << { type: :queue_wait, handler: block }
        self
      end

      # Register queue timeout callback
      #
      # @yield [request] Called when request times out
      # @return [ModelBuilder] self for chaining
      def on_queue_timeout(&block)
        @config[:callbacks] << { type: :queue_timeout, handler: block }
        self
      end

      # Prefer healthy models when using fallbacks
      #
      # @return [ModelBuilder] self for chaining
      def prefer_healthy
        @config[:prefer_healthy] = true
        self
      end

      # Register failover callback
      #
      # @yield [FailoverEvent] Called when failover occurs
      # @return [ModelBuilder] self for chaining
      def on_failover(&block)
        @config[:callbacks] << { type: :failover, handler: block }
        self
      end

      # Register error callback
      #
      # @yield [error, attempt, model] Called on each error
      # @return [ModelBuilder] self for chaining
      def on_error(&block)
        @config[:callbacks] << { type: :error, handler: block }
        self
      end

      # Register recovery callback
      #
      # @yield [model, attempt] Called on successful recovery
      # @return [ModelBuilder] self for chaining
      def on_recovery(&block)
        @config[:callbacks] << { type: :recovery, handler: block }
        self
      end

      # Register model change callback
      #
      # @yield [old_model_id, new_model_id] Called when model changes
      # @return [ModelBuilder] self for chaining
      def on_model_change(&block)
        @config[:callbacks] << { type: :model_change, handler: block }
        self
      end

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
        @config.dup
      end

      # Pretty print configuration
      def inspect
        parts = ["#<ModelBuilder"]
        parts << "type=#{@config[:type]}" if @config[:type]
        parts << "model_id=#{@config[:model_id]}" if @config[:model_id]
        parts << "fallbacks=#{@config[:fallbacks].size}" if @config[:fallbacks].any?
        parts << "health_check" if @config[:health_check]
        parts << "retry=#{@config[:retry_policy][:max_attempts]}" if @config[:retry_policy]
        "#{parts.join(" ")}>"
      end

      private

      def with(**kwargs)
        @config.merge!(kwargs)
        self
      end

      def configure_local_server(type)
        server = LOCAL_SERVERS[type]
        @config[:api_base] = "http://#{server[:host]}:#{server[:port]}/v1"
        @config[:api_key] = "not-needed"
      end

      def create_base_model
        return @config[:existing_model] if @config[:existing_model]

        type = @config[:type] || :openai
        class_name = MODEL_TYPES[type] || MODEL_TYPES[:openai]
        model_class = Smolagents.const_get(class_name)

        model_args = {
          model_id: @config[:model_id] || "default",
          api_key: @config[:api_key],
          api_base: @config[:api_base],
          temperature: @config[:temperature],
          max_tokens: @config[:max_tokens],
          timeout: @config[:timeout]
        }.compact

        model_class.new(**model_args)
      end

      def apply_health_check(model)
        return unless @config[:health_check]

        # Extend with ModelHealth if not already included
        return if model.singleton_class.include?(Concerns::ModelHealth)

        model.extend(Concerns::ModelHealth)
      end

      def apply_queue(model)
        return unless @config[:queue]

        # Extend with RequestQueue
        model.extend(Concerns::RequestQueue) unless model.singleton_class.include?(Concerns::RequestQueue)

        model.enable_queue(**@config[:queue].compact)
      end

      def apply_reliability(model)
        has_reliability = @config[:retry_policy] || @config[:fallbacks].any? || @config[:prefer_healthy]
        return unless has_reliability

        # Extend with ModelReliability
        unless model.singleton_class.include?(Concerns::ModelReliability)
          # Save original generate method
          original = model.method(:generate)
          model.define_singleton_method(:original_generate) { |*args, **kwargs| original.call(*args, **kwargs) }
          model.extend(Concerns::ModelReliability)
        end

        # Apply retry policy
        model.with_retry(**@config[:retry_policy]) if @config[:retry_policy]

        # Apply fallbacks
        @config[:fallbacks].each do |fallback|
          fb_model = fallback.is_a?(Proc) ? fallback.call : fallback
          model.with_fallback(fb_model)
        end

        # Apply prefer_healthy
        return unless @config[:prefer_healthy]

        cache = @config.dig(:health_check, :cache_for) || 5
        model.prefer_healthy(cache_health_for: cache)
      end

      def apply_callbacks(model)
        @config[:callbacks].each do |callback|
          case callback[:type]
          when :failover
            model.on_failover(&callback[:handler]) if model.respond_to?(:on_failover)
          when :error
            model.on_error(&callback[:handler]) if model.respond_to?(:on_error)
          when :recovery
            model.on_recovery(&callback[:handler]) if model.respond_to?(:on_recovery)
          when :model_change
            model.on_model_change(&callback[:handler]) if model.respond_to?(:on_model_change)
          when :queue_wait
            model.on_queue_wait(&callback[:handler]) if model.respond_to?(:on_queue_wait)
          when :queue_timeout
            model.on_queue_timeout(&callback[:handler]) if model.respond_to?(:on_queue_timeout)
          end
        end
      end
    end
  end
end
