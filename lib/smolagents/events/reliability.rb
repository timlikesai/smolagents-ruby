module Smolagents
  module Events
    # Configuration events
    define_event :ConfigurationChanged,
                 fields: %i[],
                 defaults: {}

    # Health check events (model reliability)
    define_event :HealthCheckRequested,
                 fields: %i[model_id check_type],
                 predicates: { full: :full, cached: :cached },
                 predicate_field: :check_type

    define_event :HealthCheckCompleted,
                 fields: %i[model_id status latency_ms error],
                 predicates: { healthy: :healthy, degraded: :degraded, unhealthy: :unhealthy },
                 predicate_field: :status,
                 defaults: { error: nil }

    # Model discovery events
    define_event :ModelDiscovered,
                 fields: %i[model_id provider capabilities],
                 freeze: [:capabilities],
                 defaults: { capabilities: {} }

    define_event :ModelChanged,
                 fields: %i[from_model_id to_model_id]

    # Circuit breaker events
    define_event :CircuitStateChanged,
                 fields: %i[circuit_name from_state to_state error_count cool_off_until],
                 predicates: { closed: :closed, half_open: :half_open, open: :open },
                 predicate_field: :to_state

    # Rate limiting events
    define_event :RateLimitViolated,
                 fields: %i[tool_name retry_after request_count limit_interval]

    # Request queue events
    define_event :QueueRequestStarted,
                 fields: %i[model_id queue_depth wait_time]

    define_event :QueueRequestCompleted,
                 fields: %i[model_id duration success],
                 predicates: { success: true, failure: false },
                 predicate_field: :success
  end
end
