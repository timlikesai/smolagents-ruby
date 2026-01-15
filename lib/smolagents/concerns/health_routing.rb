module Smolagents
  module Concerns
    # Health-based routing for model reliability chains.
    #
    # Provides methods to enable health-aware request routing
    # that skips unhealthy models in a fallback chain.
    #
    # @example Health-based routing
    #   model.prefer_healthy.with_fallback(backup)
    module HealthRouting
      # Prefer healthy models - check health before generating
      #
      # @param cache_health_for [Integer] Cache health check for N seconds
      # @return [self] For chaining
      def prefer_healthy(cache_health_for: 5)
        @prefer_healthy = true
        @health_cache_duration = cache_health_for
        self
      end

      # Check if health-based routing is enabled.
      #
      # @return [Boolean] True if prefer_healthy was called
      def prefer_healthy?
        @prefer_healthy || false
      end

      # Get the health cache duration.
      #
      # @return [Integer, nil] Cache duration in seconds or nil
      def health_cache_duration
        @health_cache_duration
      end

      # Check if a model should be skipped due to health check failure.
      #
      # @param model [Model] Model to check
      # @return [Boolean] True if model should be skipped
      def should_skip_unhealthy?(model)
        return false unless @prefer_healthy
        return false unless model.respond_to?(:healthy?)

        !model.healthy?(cache_for: @health_cache_duration)
      end

      # Check if any model in the chain is healthy
      #
      # @param models [Array<Model>] Models to check
      # @return [Boolean] True if at least one model is healthy
      def any_model_healthy?(models)
        models.any? do |model|
          model.respond_to?(:healthy?) && model.healthy?(cache_for: 5)
        end
      end

      # Get the first healthy model in the chain
      #
      # @param models [Array<Model>] Models to check
      # @return [Model, nil] First healthy model or nil
      def first_healthy_model(models)
        models.find do |model|
          !model.respond_to?(:healthy?) || model.healthy?(cache_for: 5)
        end
      end

      # Clear health routing configuration.
      #
      # @return [self] For chaining
      def clear_health_routing
        @prefer_healthy = false
        @health_cache_duration = nil
        self
      end
    end
  end
end
