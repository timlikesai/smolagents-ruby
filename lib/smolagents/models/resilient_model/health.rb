# frozen_string_literal: true

module Smolagents
  module Models
    module ResilientModelConcerns
      # Health-based routing for resilient model generation.
      #
      # Provides methods to enable health-aware request routing that
      # skips unhealthy models in a fallback chain.
      #
      # @example Enable health routing
      #   resilient.prefer_healthy(cache_health_for: 10)
      module Health
        # Enable health-based routing.
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
        # @return [Boolean]
        def prefer_healthy? = @prefer_healthy

        # Check if any model in the chain is healthy.
        #
        # @return [Boolean]
        def any_healthy?
          model_chain.any? do |model|
            model.respond_to?(:healthy?) && model.healthy?(cache_for: @health_cache_duration)
          end
        end

        # Get the first healthy model in the chain.
        #
        # @return [Model, nil]
        def first_healthy
          model_chain.find do |model|
            !model.respond_to?(:healthy?) || model.healthy?(cache_for: @health_cache_duration)
          end
        end

        private

        # Check if a model should be skipped due to health failure.
        #
        # @param model [Model] Model to check
        # @param next_model [Model, nil] Next model in chain
        # @param attempt [Integer] Current attempt number
        # @return [Boolean] True if should skip
        def skip_unhealthy?(model, next_model, attempt)
          return false unless @prefer_healthy
          return false unless model.respond_to?(:healthy?)
          return false if model.healthy?(cache_for: @health_cache_duration)

          notify_failover(model, next_model, AgentError.new("Health check failed"), attempt)
          true
        end
      end
    end
  end
end
