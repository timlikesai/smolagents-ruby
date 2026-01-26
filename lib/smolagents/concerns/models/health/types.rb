module Smolagents
  module Concerns
    module ModelHealth
      # Default thresholds for health status determination
      # Values sourced from Config.defaults[:health] if available
      HEALTH_THRESHOLDS = (Config.defaults_for(:health) || {
        healthy_latency_ms: 1000,      # Under 1s = healthy
        degraded_latency_ms: 5000,     # 1-5s = degraded
        timeout_ms: 10_000             # Over 10s = timeout
      }).freeze

      # Class-level health configuration
      module ClassMethods
        # Configure or retrieve health check thresholds at class level.
        #
        # Acts as both getter and setter following Ruby DSL conventions.
        # When called with arguments, sets custom thresholds (merged with defaults).
        # When called without arguments, returns current thresholds.
        #
        # @param healthy_latency_ms [Integer] Response time for healthy status (default: 1000ms)
        # @param degraded_latency_ms [Integer] Response time for degraded status (default: 5000ms)
        # @param timeout_ms [Integer] Maximum request time before timeout (default: 10000ms)
        # @return [Hash] Current thresholds
        #
        # @example Setting thresholds in class definition
        #   class FastModel < OpenAIModel
        #     health_thresholds healthy_latency_ms: 500, degraded_latency_ms: 2000
        #   end
        def health_thresholds(**thresholds)
          @health_thresholds = HEALTH_THRESHOLDS.merge(thresholds) unless thresholds.empty?
          @health_thresholds || HEALTH_THRESHOLDS
        end
      end
    end
  end
end
