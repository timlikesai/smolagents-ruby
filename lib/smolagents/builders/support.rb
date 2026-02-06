require_relative "support/validators"
require_relative "support/validated_setter"
require_relative "support/introspection"
require_relative "support/flexible_input"

module Smolagents
  module Builders
    # Helper modules for building fluent DSL interfaces.
    #
    # - Validators: Pre-built validation lambdas
    # - ValidatedSetter: Check-validate-update macro for immutable setters
    # - Introspection: Builder method discovery and documentation
    # - FlexibleInput: Polymorphic argument resolution
    module Support
    end
  end
end
