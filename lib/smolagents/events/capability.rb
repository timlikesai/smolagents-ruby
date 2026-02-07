module Smolagents
  module Events
    # Capability events (consolidated: CapabilityProbed + CapabilityLearned + CapabilityFallback)
    define_event :CapabilityEvent,
                 fields: %i[phase url server_type feature supported
                            from_endpoint to_endpoint missing_capability],
                 predicates: { probed: :probed, learned: :learned, fallback: :fallback },
                 predicate_field: :phase,
                 defaults: { url: nil, server_type: nil, feature: nil, supported: false,
                             from_endpoint: nil, to_endpoint: nil, missing_capability: nil },
                 category: :capability, description: "Fired during capability discovery lifecycle"
  end
end
