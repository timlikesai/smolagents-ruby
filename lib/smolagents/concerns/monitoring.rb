require_relative "monitoring/monitorable"
require_relative "monitoring/auditable"

module Smolagents
  module Concerns
    # Unified monitoring concern for step tracking and audit logging.
    #
    # Combines step-level monitoring (timing, metrics) with audit logging
    # (request tracking, service/operation logging) for comprehensive observability.
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
