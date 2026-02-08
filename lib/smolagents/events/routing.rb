# frozen_string_literal: true

module Smolagents
  module Events
    # Tool routing events (consolidated: ToolRouted + DispatcherError)
    define_event :ToolRouted,
                 fields: %i[source confidence tool_count latency_ms fallback_used],
                 defaults: { latency_ms: nil, fallback_used: false },
                 category: :tools, description: "Fired when tool routing completes"

    define_event :DispatcherError,
                 fields: %i[error model_id fallback_to],
                 defaults: { model_id: nil, fallback_to: :primary },
                 category: :errors, description: "Fired when dispatcher model fails"

    define_event :ToolRoutingCompleted,
                 fields: %i[source confidence fallback_used tool_count latency_ms],
                 defaults: { latency_ms: nil },
                 category: :tools, description: "Fired when tool routing decision is made"

    define_event :ToolRoutingError,
                 fields: %i[error fallback],
                 defaults: { fallback: :primary },
                 category: :errors, description: "Fired when tool routing fails"
  end
end
