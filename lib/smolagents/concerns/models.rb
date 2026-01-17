require_relative "models/health"
require_relative "models/reliability"
require_relative "models/queue"

module Smolagents
  module Concerns
    # Model behavior concerns for LLM adapters.
    #
    # This module namespace organizes concerns for model reliability,
    # health monitoring, and request management.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern          | Depends On                        | Depended By        | Auto-Includes                 |
    #   |------------------|-----------------------------------|--------------------|------------------------------ |
    #   | ModelHealth      | -                                 | HealthRouting      | Checks, Discovery             |
    #   | ModelReliability | Events::Emitter, Events::Consumer | -                  | ModelFallback, HealthRouting, |
    #   |                  |                                   |                    | RetryExecution, Reliability   |
    #   | RequestQueue     | -                                 | -                  | Operations, Worker, Types     |
    #
    # == Sub-concern Composition
    #
    #   ModelHealth
    #       |
    #       +-- Checks: health_check(), healthy?(), unhealthy?()
    #       +-- Discovery: available_models(), loaded_model()
    #
    #   ModelReliability
    #       |
    #       +-- Events::Emitter (via auto-include)
    #       +-- Events::Consumer (via auto-include)
    #       +-- ModelFallback: with_fallback(), fallback_chain
    #       +-- HealthRouting: prefer_healthy(), should_skip_unhealthy?()
    #       +-- RetryExecution: try_model_with_retry()
    #       +-- ReliabilityNotifications: notify_retry(), notify_failover()
    #       +-- Reliability::Configuration: with_retry(), reset_reliability()
    #       +-- Reliability::Subscriptions: on_failover(), on_error()
    #       +-- Reliability::Generation: reliable_generate(), any_healthy?()
    #
    #   RequestQueue
    #       |
    #       +-- Queue::Types: QueuedRequest, QueueConfig
    #       +-- Queue::Operations: enqueue(), process_queue()
    #       +-- Queue::Worker: start_worker(), stop_worker()
    #
    # == Instance Variables Set
    #
    # *ModelHealth*:
    # - @health_thresholds [HealthThresholds] - Latency warning/critical thresholds
    # - @last_health_check [HealthResult] - Cached last health check result
    # - @model_change_callbacks [Array] - Callbacks for model change detection
    #
    # *ModelReliability*:
    # - @retry_policy [RetryPolicy] - Configuration for retry behavior
    # - @fallback_chain [Array<Model>] - Ordered fallback models
    # - @prefer_healthy [Boolean] - Whether to skip unhealthy models
    # - @event_queue [Thread::Queue] - Event queue (from Emitter)
    # - @event_handlers [Hash] - Registered handlers (from Consumer)
    #
    # *RequestQueue*:
    # - @request_queue [Thread::Queue] - Pending requests
    # - @queue_config [QueueConfig] - Queue configuration
    # - @worker_thread [Thread] - Background worker thread
    #
    # == External Dependencies
    #
    # - Events::Emitter (auto-included by ModelReliability)
    # - Events::Consumer (auto-included by ModelReliability)
    #
    # == Initialization Order
    #
    # 1. Include ModelHealth first (provides health checking for routing)
    # 2. Include ModelReliability second (uses health checks for routing)
    # 3. Include RequestQueue last if needed (independent, can wrap reliability)
    #
    # @!endgroup
    #
    # == Available Concerns
    #
    # - {ModelHealth} - Health checks, discovery, and model listing
    # - {ModelReliability} - Retry, fallback chains, and failover
    # - {RequestQueue} - Serialized request execution with rate limiting
    #
    # == Composition
    #
    # These concerns compose together for production-grade reliability:
    #
    #   class ProductionModel < Model
    #     include Concerns::ModelHealth
    #     include Concerns::ModelReliability
    #
    #     def generate(messages, **)
    #       reliable_generate(messages, **)  # Uses retry + fallback
    #     end
    #   end
    #
    # == Typical Usage Pattern
    #
    #   # Configure a model with reliability
    #   model = OpenAIModel.new(api_key: key)
    #     .with_retry(max_attempts: 3)
    #     .with_fallback(backup_model)
    #     .prefer_healthy
    #
    #   # Subscribe to events
    #   model.on_failover { |e| log("Failover: #{e.from_model_id}") }
    #
    #   # Use reliable_generate for automatic retry/failover
    #   response = model.reliable_generate(messages)
    #
    # @example Building a resilient model
    #   class MyModel
    #     include Concerns::ModelHealth
    #     include Concerns::ModelReliability
    #   end
    #
    # @see ModelHealth For health checks and discovery
    # @see ModelReliability For failover and retry
    # @see RequestQueue For serialized execution
    module Models
    end
  end
end
