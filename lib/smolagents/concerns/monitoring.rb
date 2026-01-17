require_relative "monitoring/monitorable"
require_relative "monitoring/auditable"

module Smolagents
  module Concerns
    # Unified monitoring concern for step tracking and audit logging.
    #
    # Combines step-level monitoring (timing, metrics) with audit logging
    # (request tracking, service/operation logging) for comprehensive observability.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern     | Depends On       | Depended By       | Auto-Includes  |
    #   |-------------|------------------|-------------------|----------------|
    #   | Monitorable | Events::Emitter  | Monitoring,       | Events::Emitter|
    #   |             |                  | ReActLoop::Exec   |                |
    #   | Auditable   | -                | Monitoring,       | -              |
    #   |             |                  | ApiClient         |                |
    #   | Monitoring  | Monitorable,     | -                 | Monitorable,   |
    #   |             | Auditable        |                   | Auditable      |
    #
    # == Sub-concern Methods
    #
    #   Monitorable
    #       +-- monitor_step(name, metadata: {}, &block) - Wrap step with timing
    #       +-- track_tokens(usage) - Add to cumulative token count
    #       +-- total_token_usage - Get total tokens since reset
    #       +-- reset_monitoring - Clear counters and history
    #       +-- step_monitors - Get hash of StepMonitor instances
    #
    #   Auditable
    #       +-- with_audit_log(service:, operation:, &block) - Log API call
    #       +-- audit_log_entry(service:, operation:, duration:, **) - Record entry
    #       +-- audit_history - Get list of audit entries
    #
    # == Instance Variables Set
    #
    # *Monitorable*:
    # - @total_tokens [TokenUsage] - Cumulative token usage
    # - @step_history [Array] - Historical step data
    # - @step_monitors [Hash] - StepMonitor instances by name
    # - @event_queue [Thread::Queue] - Event queue (from Emitter)
    #
    # *Auditable*:
    # - @audit_history [Array] - List of audit log entries
    #
    # == Events Emitted (Monitorable)
    #
    # - Events::ErrorOccurred - Emitted on step failure (if connected)
    #
    # == External Dependencies
    #
    # *Monitorable*:
    # - Events::Emitter (auto-included for event emission)
    #
    # @!endgroup
    #
    # @example Full monitoring support
    #   class MyAgent
    #     include Concerns::Monitoring
    #
    #     def execute_step(name)
    #       monitor_step(name) do |monitor|
    #         with_audit_log(service: "openai", operation: "chat") do
    #           result = perform_operation
    #           monitor.record_metric("tokens", result.tokens)
    #           result
    #         end
    #       end
    #     end
    #   end
    #
    # @see Monitorable For step timing and metrics
    # @see Auditable For request audit logging
    module Monitoring
      include Monitorable
      include Auditable
    end
  end
end
