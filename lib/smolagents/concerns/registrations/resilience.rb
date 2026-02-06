# Resilience, isolation, and orchestration concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r| # rubocop:disable Metrics/BlockLength -- registration data
      # === Orchestration ===
      r.register :wave_scheduler,
                 Smolagents::Concerns::Orchestration::WaveScheduler,
                 category: :orchestration,
                 dependencies: %i[events_emitter],
                 provides: %i[compute_waves build_wave_plan execute_waves],
                 description: "Wave-based parallel task execution"

      r.register :task_dispatch,
                 Smolagents::Concerns::Orchestration::TaskDispatch,
                 category: :orchestration,
                 dependencies: %i[events_emitter events_consumer],
                 provides: %i[dispatch_actionable_tasks dispatch_unblocked],
                 description: "Event-driven task dispatch to work queue"

      # === Resilience ===
      r.register :circuit_breaker,
                 Smolagents::Concerns::CircuitBreaker,
                 category: :resilience,
                 provides: %i[with_circuit_breaker],
                 description: "Fail-fast circuit breaker pattern"

      r.register :rate_limiter,
                 Smolagents::Concerns::RateLimiter,
                 category: :resilience,
                 provides: %i[enforce_rate_limit! rate_limit_ok? retry_after],
                 description: "API rate limiting with configurable cooldown"

      r.register :resilience,
                 Smolagents::Concerns::Resilience,
                 category: :resilience,
                 dependencies: %i[circuit_breaker rate_limiter],
                 provides: [:resilient_call],
                 description: "Combined rate limiting and circuit breaking"

      r.register :retry_policy,
                 Smolagents::Concerns::RetryPolicy,
                 category: :resilience,
                 provides: %i[build_policy delay_for_attempt should_retry?],
                 description: "Configurable retry policies with exponential backoff"

      r.register :retryable,
                 Smolagents::Concerns::Retryable,
                 category: :resilience,
                 dependencies: [:retry_policy],
                 provides: %i[with_retry retryable_errors],
                 description: "Block execution with retry logic"

      r.register :tool_retry,
                 Smolagents::Concerns::ToolRetry,
                 category: :resilience,
                 dependencies: [:retryable],
                 provides: %i[retry_tool_execution tool_retry_policy],
                 description: "Tool-specific retry with backoff"

      # === Isolation ===
      r.register :tool_isolation,
                 Smolagents::Concerns::Isolation::ToolIsolation,
                 category: :isolation,
                 dependencies: [:events_emitter],
                 provides: %i[with_tool_isolation],
                 description: "Resource-bounded tool execution with timeout and limits"
    end
  end
end
