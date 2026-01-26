# Retry result types for event-driven retry logic.
#
# These types allow retry decisions to be communicated without blocking.
# The caller can handle delays through event loops, schedulers, or Fibers
# rather than blocking with sleep.
#
# @example Using try_once
#   result = retry_helper.try_once(policy:, attempt: 1) { api_call }
#   case result
#   in Success[value:]
#     return value
#   in RetryNeeded[backoff_seconds:, attempt:]
#     schedule_after(backoff_seconds) { retry with attempt + 1 }
#   end
#
module Smolagents
  module Types
    # Information about a needed retry.
    #
    # @!attribute [r] backoff_seconds
    #   @return [Float] Seconds to wait before retrying
    # @!attribute [r] attempt
    #   @return [Integer] Attempt number just completed
    # @!attribute [r] max_attempts
    #   @return [Integer] Maximum attempts allowed
    # @!attribute [r] error
    #   @return [StandardError] Error that triggered retry
    RetryInfo = Data.define(:backoff_seconds, :attempt, :max_attempts, :error) do
      # Check if more retries are available.
      # @return [Boolean]
      def retries_remaining? = attempt < max_attempts
    end

    # Result of a single retry attempt.
    #
    # @!attribute [r] status
    #   @return [Symbol] One of :success, :retry_needed, :exhausted, :error
    # @!attribute [r] value
    #   @return [Object, nil] Result value on success
    # @!attribute [r] retry_info
    #   @return [RetryInfo, nil] Retry information when retry_needed
    # @!attribute [r] error
    #   @return [StandardError, nil] Final error when exhausted/error
    RetryResult = Data.define(:status, :value, :retry_info, :error) do
      # @return [Boolean] True if operation succeeded
      def success? = status == :success

      # @return [Boolean] True if retry is needed and possible
      def retry_needed? = status == :retry_needed

      # @return [Boolean] True if all retries exhausted
      def exhausted? = status == :exhausted

      # @return [Boolean] True if non-retryable error occurred
      def error? = status == :error

      class << self
        # Create a success result.
        # @param value [Object] The successful result
        # @return [RetryResult]
        def success(value)
          new(status: :success, value:, retry_info: nil, error: nil)
        end

        # Create a retry-needed result.
        # @param info [RetryInfo] Retry information
        # @return [RetryResult]
        def needs_retry(info)
          new(status: :retry_needed, value: nil, retry_info: info, error: nil)
        end

        # Create an exhausted result.
        # @param error [StandardError] The last error
        # @return [RetryResult]
        def exhausted(error)
          new(status: :exhausted, value: nil, retry_info: nil, error:)
        end

        # Create an error result (non-retryable).
        # @param error [StandardError] The error
        # @return [RetryResult]
        def error(error)
          new(status: :error, value: nil, retry_info: nil, error:)
        end
      end
    end
  end
end
