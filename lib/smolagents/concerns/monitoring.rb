require_relative "monitoring/auditable"
require_relative "monitoring/monitorable"

module Smolagents
  module Concerns
    # Monitoring concerns for observability and auditing.
    #
    # Provides concerns for logging, metrics, and audit trails.
    #
    # == Sub-Modules
    #
    #   Auditable
    #       Record audit events for compliance and debugging
    #
    #   Monitorable
    #       Step logging, monitoring, and token tracking
    #
    # @see Auditable For audit event recording
    # @see Monitorable For step-level monitoring
    module Monitoring
    end
  end
end
