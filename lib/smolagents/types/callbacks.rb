require_relative "callbacks/errors"
require_relative "callbacks/type_resolver"
require_relative "callbacks/signature"
require_relative "callbacks/definitions"
require_relative "callbacks/registry"

module Smolagents
  module Types
    # Callback validation and type definitions.
    #
    # The Callbacks module provides type-safe callback registration and
    # validation for agent events. Each event has a defined signature
    # specifying required and optional arguments with type constraints.
    #
    # @example Validating callback arguments
    #   Types::Callbacks.validate_args!(:after_step, { step: action_step, monitor: mon })
    #
    # @example Checking valid events
    #   Types::Callbacks.valid_event?(:before_step)  # => true
    #   Types::Callbacks.events  # => [:before_step, :after_step, ...]
    module Callbacks
      extend Registry

      # Legacy constant for backwards compatibility during transition.
      # Use Callbacks.signature_for(event) instead.
      SIGNATURES = SignatureBuilder.build_all
    end
  end
end
