module Smolagents
  module Types
    module Callbacks
      # Raised when an invalid callback event is registered or validated.
      class InvalidCallbackError < ArgumentError; end

      # Raised when callback arguments fail validation.
      # Triggered when required arguments are missing, have wrong types, or fail type constraints.
      class InvalidArgumentError < ArgumentError; end
    end
  end
end
