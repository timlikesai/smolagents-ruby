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
          temperature: cfg[:temperature], max_tokens: cfg[:max_tokens], timeout: cfg[:timeout] }.compact
      end

      def apply_health_check(model)
        return unless configuration[:health_check]
        return if model.singleton_class.include?(Concerns::ModelHealth)

        model.extend(Concerns::ModelHealth)
      end

      def apply_queue(model)
        return unless configuration[:queue]

        model.extend(Concerns::RequestQueue) unless model.singleton_class.include?(Concerns::RequestQueue)
        model.enable_queue(**configuration[:queue].compact)
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

      RETRY_DEFAULTS = {
        max_attempts: 3, base_interval: 1.0, max_interval: 30.0,
        backoff: :exponential, jitter: 0.5
      }.freeze

      def apply_retry_policy(model, policy_config)
        return unless policy_config

        opts = RETRY_DEFAULTS.merge(policy_config.slice(*RETRY_DEFAULTS.keys))
        opts[:on] ||= Concerns::RetryPolicyClassification::RETRIABLE_ERRORS
        model.with_retry(**opts)
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
