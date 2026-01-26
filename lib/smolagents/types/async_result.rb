module Smolagents
  module Types
    # Error wrapper for failed async tool execution.
    #
    # @!attribute [r] id
    #   @return [String] Error identifier for correlation
    # @!attribute [r] message
    #   @return [String] Error message
    AsyncToolError = Data.define(:id, :message) do
      def to_s = message
    end

    # Result wrapper for async execution with index tracking.
    #
    # Immutable Data class tracking whether async execution succeeded
    # or failed, with the result value and any error.
    #
    # @!attribute [r] index
    #   @return [Integer] Position in original tool_calls array
    # @!attribute [r] value
    #   @return [Object] Result value on success, nil on failure
    # @!attribute [r] error
    #   @return [StandardError, nil] Error object on failure, nil on success
    AsyncResult = Data.define(:index, :value, :error) do
      # Create a successful result.
      # @param index [Integer] Position in tool_calls array
      # @param value [Object] Result value
      # @return [AsyncResult] Success result
      def self.success(index:, value:) = new(index:, value:, error: nil)

      # Create a failed result.
      # @param index [Integer] Position in tool_calls array
      # @param error [StandardError] Error that occurred
      # @return [AsyncResult] Failure result
      def self.failure(index:, error:) = new(index:, value: nil, error:)

      # Check if execution succeeded.
      # @return [Boolean] true if no error occurred
      def success? = error.nil?

      # Check if execution failed.
      # @return [Boolean] true if error occurred
      def failure? = !success?
    end
  end
end
