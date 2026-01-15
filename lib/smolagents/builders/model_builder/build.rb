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
      #
      # @return [Model] Configured model with reliability features
      def build
        model = create_base_model
        apply_health_check(model)
        apply_queue(model)
        apply_reliability(model)
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

      def apply_reliability(model)
        cfg = configuration
        return unless cfg[:retry_policy] || cfg[:fallbacks].any? || cfg[:prefer_healthy]

        ensure_reliability_concern(model)
        model.with_retry(**cfg[:retry_policy]) if cfg[:retry_policy]
        apply_fallbacks(model, cfg[:fallbacks])
        apply_prefer_healthy(model, cfg) if cfg[:prefer_healthy]
      end

      def ensure_reliability_concern(model)
        return if model.singleton_class.include?(Concerns::ModelReliability)

        original = model.method(:generate)
        model.define_singleton_method(:original_generate) { |*args, **kwargs| original.call(*args, **kwargs) }
        model.extend(Concerns::ModelReliability)
      end

      def apply_fallbacks(model, fallbacks)
        fallbacks.each do |fallback|
          fb_model = fallback.is_a?(Proc) ? fallback.call : fallback
          model.with_fallback(fb_model)
        end
      end

      def apply_prefer_healthy(model, cfg)
        cache = cfg.dig(:health_check, :cache_for) || 5
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
