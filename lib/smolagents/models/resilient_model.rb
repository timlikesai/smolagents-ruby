# frozen_string_literal: true

require "delegate"
require_relative "../concerns/resilience/retry_policy"
require_relative "../concerns/resilience/events"
require_relative "../events"
require_relative "resilient_model/retry"
require_relative "resilient_model/fallback"
require_relative "resilient_model/health"
require_relative "resilient_model/notifications"

module Smolagents
  module Models
    # Decorator that adds resilience capabilities to any model.
    # Provides retry, fallback, and health-based routing.
    #
    # @example resilient = ResilientModel.new(model, retry_policy: RetryPolicy.default)
    # @example resilient.with_retry(max_attempts: 5).with_fallback(backup)
    # @see Concerns::RetryPolicy
    class ResilientModel < SimpleDelegator
      include Events::Emitter
      include Events::Consumer
      include ResilientModelConcerns::Retry
      include ResilientModelConcerns::Fallback
      include ResilientModelConcerns::Health
      include ResilientModelConcerns::Notifications

      attr_reader :retry_policy, :fallbacks, :health_cache_duration

      # @param model [Model] The base model to wrap
      # @param retry_policy [Concerns::RetryPolicy, nil] Retry configuration
      # @param fallbacks [Array<Model>] Backup models in priority order
      # @param prefer_healthy [Boolean] Skip unhealthy models
      # @param health_cache_duration [Integer] Health cache time in seconds
      def initialize(model, retry_policy: nil, fallbacks: [], prefer_healthy: false, health_cache_duration: 5)
        super(model)
        @retry_policy = retry_policy
        @fallbacks = fallbacks.dup.freeze
        @prefer_healthy = prefer_healthy
        @health_cache_duration = health_cache_duration
        setup_consumer
      end

      # @return [Model] The underlying model instance
      def base_model = __getobj__

      # @return [String] The model identifier
      def model_id = base_model.model_id

      # @param messages [Array<ChatMessage>] The conversation history
      # @return [ChatMessage] Model response from primary or fallback
      def generate(messages, **)
        return base_model.generate(messages, **) unless resilience_enabled?

        reliable_generate(messages, **)
      end

      # @raise [AgentError] When all models fail
      def reliable_generate(messages, **)
        state = { last_error: nil, attempt: 0 }
        result = try_chain(messages, state, **)
        return result if result

        raise state[:last_error] || AgentError.new("All models failed")
      end

      # @return [self]
      def reset_reliability
        @retry_policy = nil
        @fallbacks = [].freeze
        @prefer_healthy = false
        @health_cache_duration = 5
        clear_handlers
        self
      end

      # @return [Hash] Current resilience configuration
      def reliability_config
        { retry_policy: @retry_policy || Concerns::RetryPolicy.default,
          fallback_count:, prefer_healthy: prefer_healthy?, health_cache_duration: @health_cache_duration }
      end

      # @!group Event Subscriptions
      def on_failover(&) = on(Events::FailoverOccurred, &)
      def on_error(&) = on(Events::ErrorOccurred, &)
      def on_recovery(&) = on(Events::RecoveryCompleted, &)
      def on_retry(&) = on(Events::RetryRequested, &)
      # @!endgroup

      private

      def resilience_enabled? = @retry_policy || @fallbacks.any? || @prefer_healthy
    end
  end
end
