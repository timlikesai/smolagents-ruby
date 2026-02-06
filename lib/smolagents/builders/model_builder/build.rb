module Smolagents
  module Builders
    module ModelBuilderBuild
      # Build logic for ModelBuilder.
      #
      # Provides the build method and private helpers for applying
      # configuration to the model instance.
      # Build the configured model.
      #
      # Creates and configures a Model instance with all reliability features.
      # Uses ModelReliability concern for retry/fallback/health routing.
      #
      # @return [Model] Configured model with reliability features
      def build
        model = create_base_model
        apply_health_check(model)
        apply_queue(model)
        apply_request_logging(model)
        wrap_with_resilience(model)
        apply_callbacks(model)
        model
      end

      private

      def create_base_model
        return configuration[:existing_model] if configuration[:existing_model]

        resolve_model_class.new(**model_args)
      end

      def resolve_model_class
        type = configuration[:type] || :openai
        class_name = MODEL_TYPES[type] || MODEL_TYPES[:openai]
        Smolagents.const_get(class_name)
      end

      def model_args
        cfg = configuration
        { model_id: cfg[:model_id] || "default", api_key: cfg[:api_key], api_base: cfg[:api_base],
          temperature: cfg[:temperature], max_tokens: cfg[:max_tokens], timeout: cfg[:timeout],
          server_capabilities: cfg[:server_capabilities],
          tool_calling_mode: cfg[:tool_calling_mode] }.compact
      end

      def apply_health_check(model)
        return unless configuration[:health_check]
        return if model.singleton_class.include?(Concerns::ModelHealth)

        model.extend(Concerns::ModelHealth)
        model.configure_health_check(**configuration[:health_check]) if model.respond_to?(:configure_health_check)
      end

      def apply_queue(model)
        return unless configuration[:queue]

        model.extend(Concerns::RequestQueue) unless model.singleton_class.include?(Concerns::RequestQueue)
        model.enable_queue(**configuration[:queue].compact)
      end

      def apply_request_logging(model)
        return unless configuration[:request_logging]
        return if model.singleton_class.include?(Models::Model::RequestLogging)

        model.extend(Models::Model::RequestLogging)
        model.initialize_request_logging
      end

      def wrap_with_resilience(model)
        cfg = configuration
        return model unless cfg[:retry_policy] || cfg[:fallbacks].any? || cfg[:prefer_healthy]

        extend_with_reliability(model)
        apply_reliability_config(model, cfg)
        model
      end

      def extend_with_reliability(model)
        return if model.singleton_class.include?(Concerns::ModelReliability)

        # Alias generate before including reliability so retry can call original
        model.define_singleton_method(:original_generate, model.method(:generate))
        model.extend(Concerns::ModelReliability)
      end

      def apply_reliability_config(model, cfg)
        apply_retry_policy(model, cfg[:retry_policy])
        resolve_fallbacks(cfg[:fallbacks]).each { model.with_fallback(it) }
        model.prefer_healthy if cfg[:prefer_healthy]
      end

      def apply_retry_policy(model, policy_config)
        return unless policy_config

        model.with_retry(**retry_opts_from_config(policy_config))
      end

      def retry_opts_from_config(config)
        overrides = config.slice(:max_attempts, :base_interval, :max_interval, :backoff, :jitter, :on)
        default_retry_opts.merge(overrides.compact)
      end

      def default_retry_opts
        policy = Types::RetryPolicy.default
        { max_attempts: policy.max_attempts, base_interval: policy.base_interval,
          max_interval: policy.max_interval, backoff: policy.backoff,
          jitter: policy.jitter, on: policy.retryable_errors }
      end

      def resolve_fallbacks(fallbacks)
        fallbacks.map do |fallback|
          fallback.is_a?(Proc) ? fallback.call : fallback
        end
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
