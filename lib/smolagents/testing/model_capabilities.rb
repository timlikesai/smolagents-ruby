require_relative "model_capabilities/inference"
require_relative "model_capabilities/formatters"
require_relative "model_capabilities/capability"
require_relative "model_capabilities/registry"

module Smolagents
  module Testing
    # Convenience aliases for top-level access
    ModelCapability = ModelCapabilities::Capability
    ModelRegistry = ModelCapabilities::Registry
  end
end
