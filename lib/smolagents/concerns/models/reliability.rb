require_relative "../resilience/retry_policy"
require_relative "../resilience/events"
require_relative "../resilience/fallback"
require_relative "../resilience/health_routing"
require_relative "../resilience/retry_execution"
require_relative "../resilience/notifications"
require_relative "reliability/configuration"
require_relative "reliability/subscriptions"
require_relative "reliability/generation"

module Smolagents
  module Concerns
    # Event-driven reliability for model failover, retry, and routing.
    #
    # Provides composable reliability primitives for LLM models:
    # - Automatic retry with exponential backoff
    # - Fallback chains for model failover
    # - Health-based routing to skip unhealthy models
    # - Event emission for monitoring and logging
    #
    # == Composition
    #
    # Auto-includes these sub-concerns:
    #
    #   ModelReliability (this concern)
    #       |
    #       +-- Events::Emitter: emit(), on()
    #       |
    #       +-- Events::Consumer: subscribe(), clear_handlers()
    #       |
    #       +-- ModelFallback: with_fallback(), fallback_chain
    #       |
    #       +-- HealthRouting: prefer_healthy(), should_skip_unhealthy?()
    #       |
    #       +-- RetryExecution: try_model_with_retry()
    #       |
    #       +-- ReliabilityNotifications: notify_retry(), notify_failover()
    #       |
    #       +-- Reliability::Configuration: with_retry(), reset_reliability()
    #       |
    #       +-- Reliability::Subscriptions: on_failover(), on_error(), etc.
    #       |
    #       +-- Reliability::Generation: reliable_generate(), any_healthy?()
    #
    # == Events Emitted
    #
    # - {Events::RetryRequested} - Before retry attempt (includes delay)
    # - {Events::FailoverOccurred} - When switching to fallback model
    # - {Events::ErrorOccurred} - On any error
    # - {Events::RecoveryCompleted} - When a retry succeeds
    #
    # @example Fallback chain
    #   model.with_fallback(backup_model).with_fallback(emergency_model)
    #
    # @example Retry with event handling
    #   model.with_retry(max_attempts: 5)
    #        .on(Events::RetryRequested) { |e| log("Retry #{e.attempt}") }
    #
    # @example Full reliability stack
    #   model.with_retry(max_attempts: 3)
    #        .with_fallback(backup_model)
    #        .prefer_healthy
    #        .on(Events::FailoverOccurred) { |e| log("#{e.from_model_id} -> #{e.to_model_id}") }
    #
    # @see ModelFallback For fallback chain management
    # @see HealthRouting For health-based routing
    # @see RetryExecution For retry logic
    # @see RetryPolicy For retry configuration
    # @see ModelHealth For health checking (separate concern)
    module ModelReliability
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.include(ModelFallback)
        base.include(HealthRouting)
        base.include(RetryExecution)
        base.include(ReliabilityNotifications)
        base.include(Reliability::Configuration)
        base.include(Reliability::Subscriptions)
        base.include(Reliability::Generation)
      end

      def self.extended(instance)
        instance.extend(Events::Emitter) unless instance.singleton_class.include?(Events::Emitter)
        instance.extend(Events::Consumer) unless instance.singleton_class.include?(Events::Consumer)
        instance.extend(ModelFallback)
        instance.extend(HealthRouting)
        instance.extend(RetryExecution)
        instance.extend(ReliabilityNotifications)
        instance.extend(Reliability::Configuration)
        instance.extend(Reliability::Subscriptions)
        instance.extend(Reliability::Generation)
      end
    end
  end
end
