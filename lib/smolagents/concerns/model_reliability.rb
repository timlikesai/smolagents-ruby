require_relative "retry_policy"
require_relative "reliability_events"
require_relative "model_fallback"
require_relative "health_routing"
require_relative "retry_execution"
require_relative "reliability_notifications"

module Smolagents
  module Concerns
    # Event-driven reliability for model failover, retry, and routing.
    #
    # Composable reliability primitives with no blocking sleeps.
    # All operations emit events that can be handled by consumers.
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
    #        .on(Events::FailoverOccurred) { |e| log("#{e.from_model_id} -> #{e.to_model_id}") }
    #
    module ModelReliability
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.include(ModelFallback)
        base.include(HealthRouting)
        base.include(RetryExecution)
        base.include(ReliabilityNotifications)
        base.extend(ClassMethods)
      end

      def self.extended(instance)
        instance.extend(Events::Emitter) unless instance.singleton_class.include?(Events::Emitter)
        instance.extend(Events::Consumer) unless instance.singleton_class.include?(Events::Consumer)
        instance.extend(ModelFallback)
        instance.extend(HealthRouting)
        instance.extend(RetryExecution)
        instance.extend(ReliabilityNotifications)
      end

      module ClassMethods
        def default_retry_policy(policy = nil)
          @default_retry_policy = policy if policy
          @default_retry_policy || RetryPolicy.default
        end
      end

      def with_retry(max_attempts: nil, base_interval: nil, max_interval: nil, backoff: nil, on: nil)
        base = @retry_policy || default_policy
        @retry_policy = RetryPolicy.new(
          max_attempts: max_attempts || base.max_attempts,
          base_interval: base_interval || base.base_interval,
          max_interval: max_interval || base.max_interval,
          backoff: backoff || base.backoff,
          retryable_errors: on || base.retryable_errors
        )
        self
      end

      def on_failover(&) = on(Events::FailoverOccurred, &)
      def on_error(&) = on(Events::ErrorOccurred, &)
      def on_recovery(&) = on(Events::RecoveryCompleted, &)
      def on_retry(&) = on(Events::RetryRequested, &)

      def reliable_generate(messages, **)
        state = { last_error: nil, attempt: 0 }
        result = try_chain(messages, state, **) do |model, next_model, msgs, st|
          try_model_in_chain(model, next_model, msgs, st, **)
        end
        return result if result

        raise state[:last_error] || AgentError.new("All models failed")
      end

      def any_healthy? = any_model_healthy?(model_chain)
      def first_healthy = first_healthy_model(model_chain)

      def reset_reliability
        @retry_policy = nil
        clear_fallbacks
        clear_health_routing
        clear_handlers
        self
      end

      def reliability_config
        {
          retry_policy: @retry_policy || RetryPolicy.default,
          fallback_count:,
          prefer_healthy: prefer_healthy?,
          health_cache_duration:
        }
      end

      private

      def default_policy
        self.class.respond_to?(:default_retry_policy) ? self.class.default_retry_policy : RetryPolicy.default
      end

      def model_retry_policy(model)
        return @retry_policy if model == self && @retry_policy
        return model.send(:retry_policy) if model.respond_to?(:retry_policy, true) && model.send(:retry_policy)

        RetryPolicy.default
      end

      def retry_policy = @retry_policy

      def try_model_in_chain(model, next_model, messages, state, **)
        return nil if skip_unhealthy?(model, next_model, state[:attempt])

        result = try_model_with_retry(model, messages, model_retry_policy(model), state[:attempt], **)
        return handle_success(model, result) if result&.dig(:success)

        state[:last_error] = result[:error]
        state[:attempt] = result[:attempt]
        notify_failover(model, next_model, state[:last_error], state[:attempt]) if next_model
        nil
      end

      def skip_unhealthy?(model, next_model, attempt)
        return false unless should_skip_unhealthy?(model)

        notify_failover(model, next_model, AgentError.new("Health check failed"), attempt)
        true
      end

      def handle_success(model, result)
        notify_recovery(model, result[:attempt]) if result[:attempt] > 1
        result[:response]
      end
    end
  end
end
