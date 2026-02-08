module Smolagents
  module Types
    # Result of a tool recovery attempt (PALADIN pattern).
    #
    # Captures the outcome of attempting to recover from a tool execution
    # failure, including the action taken, success status, and any errors.
    #
    # @example Successful recovery
    #   result = ToolRecoveryResult.success("data", attempts: 2)
    #   result.success?    # => true
    #   result.recovered?  # => true (attempts > 1)
    #
    # @example Failed recovery
    #   result = ToolRecoveryResult.failure(error, attempts: 3)
    #   result.failed?    # => true
    #   result.gave_up?   # => true (action is TERMINATE)
    #
    # @see ToolRecovery For the recovery implementation
    ToolRecoveryResult = Data.define(
      :action,
      :success,
      :attempts,
      :original_error,
      :final_result,
      :reason
    ) do
      include TypeSupport::Deconstructable

      # Whether the recovery succeeded.
      # @return [Boolean]
      def success? = success

      # Whether the recovery failed.
      # @return [Boolean]
      def failed? = !success

      # Whether recovery succeeded after retrying (attempts > 1).
      # @return [Boolean]
      def recovered? = success && attempts > 1

      # Whether recovery gave up (action is TERMINATE).
      # @return [Boolean]
      def gave_up? = action == RecoveryAction::TERMINATE

      class << self
        # Create a success result.
        #
        # @param result [Object] The tool execution result
        # @param attempts [Integer] Number of attempts made
        # @param action [Symbol] The action that led to success
        # @return [ToolRecoveryResult]
        def success(result, attempts: 1, action: RecoveryAction::RETRY)
          reason = attempts > 1 ? "Recovered after #{attempts} attempts" : "Success"
          new(
            action:,
            success: true,
            attempts:,
            original_error: nil,
            final_result: result,
            reason:
          )
        end

        # Create a failure result.
        #
        # @param error [Exception] The error that caused failure
        # @param attempts [Integer] Number of attempts made
        # @param reason [String, nil] Optional reason for failure
        # @return [ToolRecoveryResult]
        def failure(error, attempts: 1, reason: nil)
          new(
            action: RecoveryAction::TERMINATE,
            success: false,
            attempts:,
            original_error: error,
            final_result: nil,
            reason: reason || error.message
          )
        end
      end
    end
  end
end
