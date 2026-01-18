module Smolagents
  module Types
    module OutcomeComponents
      # Value unwrapping for outcome types.
      #
      # Provides the `value!` method for unwrapping successful outcomes
      # or raising errors from failed outcomes.
      module ValueUnwrapping
        # Gets the result value, raising if execution failed.
        #
        # Unwraps the value from a successful outcome, or raises the error
        # from a failed outcome. Useful in contexts where you want exceptions
        # instead of outcome values.
        #
        # @return [Object] The value from successful execution
        # @raise [StandardError] The error if execution failed
        def value!
          raise error if error?
          raise StandardError, "Operation failed: #{state}" if failed?

          value
        end
      end
    end
  end
end
