# API, models, events, monitoring, validation, sandbox, and support registrations.
module Smolagents
  module Concerns
    Registry.tap do |r| # rubocop:disable Metrics/BlockLength -- registration data
      # === API ===
      r.register :api_key,
                 Smolagents::Concerns::ApiKey,
                 category: :api,
                 provides: %i[require_api_key optional_api_key configure_provider],
                 description: "API key resolution from args or environment"

      r.register :http,
                 Smolagents::Concerns::Http,
                 category: :api,
                 provides: %i[get post safe_api_call],
                 description: "HTTP client with error handling"

      r.register :api_client,
                 Smolagents::Concerns::ApiClient,
                 category: :api,
                 dependencies: %i[http api_key],
                 provides: %i[configure_client base_url headers],
                 description: "Configured API client pattern"

      # === Monitoring ===
      r.register :auditable,
                 Smolagents::Concerns::Auditable,
                 category: :monitoring,
                 provides: %i[audit_log record_audit],
                 description: "Audit logging for agent actions"

      r.register :monitorable,
                 Smolagents::Concerns::Monitorable,
                 category: :monitoring,
                 dependencies: [:events_emitter],
                 provides: %i[monitor_step step_monitors],
                 description: "Step timing and monitoring"

      # === Validation ===
      r.register :execution_oracle,
                 Smolagents::Concerns::ExecutionOracle,
                 category: :validation,
                 provides: %i[validate_execution score_confidence generate_suggestions],
                 description: "External validation of agent execution"

      r.register :goal_drift,
                 Smolagents::Concerns::GoalDrift,
                 category: :validation,
                 provides: %i[detect_drift drift_score generate_guidance],
                 description: "Goal drift detection and correction"

      # === Sandbox ===
      r.register :ruby_safety,
                 Smolagents::Concerns::RubySafety,
                 category: :sandbox,
                 provides: %i[safe_eval allowed_methods blocked_constants],
                 description: "Ruby code safety validation"

      # === Models ===
      r.register :model_health,
                 Smolagents::Concerns::ModelHealth,
                 category: :models,
                 provides: %i[health_status healthy? degraded?],
                 description: "Model health monitoring"

      r.register :model_reliability,
                 Smolagents::Concerns::ModelReliability,
                 category: :models,
                 dependencies: %i[retry_policy events],
                 provides: %i[reliable_generate with_fallback],
                 description: "Model reliability with retry and fallback"

      r.register :request_queue,
                 Smolagents::Concerns::RequestQueue,
                 category: :models,
                 provides: %i[enqueue process_queue queue_size],
                 description: "Request queuing for rate limiting"

      # === Events ===
      r.register :events_emitter,
                 Smolagents::Events::Emitter,
                 category: :events,
                 provides: %i[emit_event on_event],
                 description: "Event emission for pub/sub"

      r.register :events_consumer,
                 Smolagents::Events::Consumer,
                 category: :events,
                 provides: %i[subscribe consume_events],
                 description: "Event subscription and consumption"

      # === Support ===
      r.register :gem_loader,
                 Smolagents::Concerns::GemLoader,
                 category: :support,
                 provides: %i[require_gem gem_available?],
                 description: "Lazy gem loading with availability checks"

      r.register :browser_mode,
                 Smolagents::Concerns::Support::BrowserMode,
                 category: :support,
                 provides: %i[headless? browser_type],
                 description: "Browser mode configuration"
    end
  end
end
