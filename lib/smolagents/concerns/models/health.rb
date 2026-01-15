require_relative "health/types"
require_relative "health/thresholds"
require_relative "health/checks"
require_relative "health/discovery"

module Smolagents
  module Concerns
    # Adds health checking and model discovery capabilities to model classes.
    #
    # This concern provides methods to check if a model server is healthy,
    # query available models, and detect when the loaded model changes.
    #
    # @example Basic health check
    #   model = OpenAIModel.lm_studio("local-model")
    #   if model.healthy?
    #     result = model.generate(messages)
    #   else
    #     puts "Model server unavailable"
    #   end
    #
    # @example Detailed health information
    #   health = model.health_check
    #   case health.status
    #   when :healthy
    #     puts "Server responding in #{health.latency_ms}ms"
    #   when :degraded
    #     puts "Slow response: #{health.latency_ms}ms"
    #   when :unhealthy
    #     puts "Server error: #{health.error}"
    #   end
    #
    # @example Model discovery
    #   models = model.available_models
    #   models.each { |m| puts "#{m.id}: #{m.owned_by}" }
    #
    #   loaded = model.loaded_model
    #   puts "Currently loaded: #{loaded&.id || 'unknown'}"
    #
    # @example Model change detection
    #   model.on_model_change do |old_model, new_model|
    #     logger.info "Model changed: #{old_model} -> #{new_model}"
    #   end
    #
    module ModelHealth
      def self.included(base)
        base.extend(ClassMethods)
        base.include(Checks)
        base.include(Discovery)
      end
    end
  end
end
