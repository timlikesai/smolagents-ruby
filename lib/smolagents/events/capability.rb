module Smolagents
  module Events
    # Emitted when probing endpoint capabilities.
    define_event :CapabilityProbed,
                 fields: %i[url server_type],
                 defaults: {}

    # Emitted when learning capability from runtime error.
    define_event :CapabilityLearned,
                 fields: %i[url feature supported],
                 defaults: { supported: false }

    # Emitted when request is adapted for capabilities.
    define_event :RequestAdapted,
                 fields: %i[url removed_params adapted_params],
                 freeze: %i[removed_params adapted_params],
                 defaults: { removed_params: [], adapted_params: {} }

    # Emitted when fallback triggered due to capability mismatch.
    define_event :CapabilityFallback,
                 fields: %i[from_endpoint to_endpoint missing_capability],
                 defaults: {}
  end
end
