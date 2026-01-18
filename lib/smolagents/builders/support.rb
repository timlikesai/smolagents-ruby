require_relative "support/validators"
require_relative "support/configurable"
require_relative "support/setter_factory"
require_relative "support/validated_setter"
require_relative "support/introspection"

module Smolagents
  module Builders
    # Helper modules for building fluent DSL interfaces.
    #
    # Provides reusable patterns for creating chainable builder methods:
    # - Validators: Pre-built validation lambdas
    # - Configurable: Immutable config update pattern
    # - SetterFactory: Generate setters from declarative config
    # - ValidatedSetter: Check-validate-update pattern
    #
    # @example Using ValidatedSetter with Validators
    #   module MySetters
    #     extend Smolagents::Builders::Support::ValidatedSetter
    #
    #     validated_setter :max_steps, validate: Support::Validators::POSITIVE_INTEGER
    #     validated_setter :temperature, validate: Support::Validators.numeric_range(0.0, 2.0)
    #   end
    #
    # @example Using SetterFactory for mutable builders
    #   module MySetters
    #     extend Smolagents::Builders::Support::SetterFactory
    #
    #     define_setters(
    #       task: { key: :task },
    #       tools: { key: :tools, transform: :flatten }
    #     )
    #   end
    module Support
    end
  end
end
