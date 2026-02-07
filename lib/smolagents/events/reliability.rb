module Smolagents
  module Events
    # Health check events (consolidated: HealthCheckRequested + HealthCheckCompleted)
    define_event :HealthCheck,
                 fields: %i[model_id phase check_type status latency_ms error],
                 predicates: { requested: :requested, completed: :completed },
                 predicate_field: :phase,
                 defaults: { check_type: nil, status: nil, latency_ms: nil, error: nil },
                 category: :resilience, description: "Fired during health check lifecycle"

    # Model reliability events (consolidated: ModelDiscovered + ModelChanged)
    define_event :ModelReliability,
                 fields: %i[phase model_id provider capabilities from_model_id to_model_id],
                 predicates: { discovered: :discovered, changed: :changed },
                 predicate_field: :phase,
                 freeze: [:capabilities],
                 defaults: { provider: nil, capabilities: {}, from_model_id: nil, to_model_id: nil },
                 category: :models, description: "Fired during model reliability lifecycle"

    define_event :CircuitStateChanged,
                 fields: %i[circuit_name from_state to_state error_count cool_off_until],
                 predicates: { closed: :closed, half_open: :half_open, open: :open },
                 predicate_field: :to_state,
                 category: :resilience, description: "Fired when circuit breaker state changes"

    define_event :RateLimitViolated,
                 fields: %i[tool_name retry_after request_count limit_interval original_request],
                 defaults: { request_count: nil, limit_interval: nil, original_request: nil },
                 category: :resilience, description: "Fired when a rate limit is violated"

    # Queue request events (consolidated: QueueRequestStarted + QueueRequestCompleted)
    define_event :QueueRequest,
                 fields: %i[model_id phase queue_depth wait_time duration success],
                 predicates: { started: :started, completed: :completed },
                 predicate_field: :phase,
                 defaults: { queue_depth: nil, wait_time: nil, duration: nil, success: nil },
                 category: :resilience, description: "Fired during queue request lifecycle"

    # Request reliability events (consolidated: RequestFailed + RequestRetried)
    define_event :RequestReliability,
                 fields: %i[model_id phase error error_message dlq_size attempt original_error],
                 predicates: { failed: :failed, retried: :retried },
                 predicate_field: :phase,
                 defaults: { error: nil, error_message: nil, dlq_size: nil,
                             attempt: nil, original_error: nil },
                 category: :errors, description: "Fired during request reliability lifecycle"

    define_event :ToolRetrying,
                 fields: %i[attempt max_attempts backoff_seconds error_message],
                 category: :tools, description: "Fired when a tool call is being retried after failure"
  end
end
