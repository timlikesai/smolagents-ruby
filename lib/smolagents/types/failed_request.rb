module Smolagents
  module Types
    # Immutable record of a failed request.
    #
    # Captures the original request, error details, and retry attempts
    # for debugging and analysis. Used by the dead letter queue (DLQ).
    #
    # @example Creating a failed request record
    #   failed = FailedRequest.new(
    #     request: original_request,
    #     error: "Faraday::TimeoutError",
    #     error_message: "execution expired",
    #     attempts: 3,
    #     failed_at: Time.now
    #   )
    #
    # @example Checking failure age
    #   failed.age  # => 120.5 (seconds since failure)
    #
    # @see Concerns::RequestQueue For queue management concern
    # @see Concerns::DeadLetterQueue For DLQ handling
    FailedRequest = Data.define(:request, :error, :error_message, :attempts, :failed_at) do
      include TypeSupport::Deconstructable

      # Time since the failure occurred.
      # @return [Float] Seconds since failure
      def age = Time.now - failed_at

      # Whether this failure is recent (within threshold).
      #
      # @param threshold [Float] Age threshold in seconds (default: 60)
      # @return [Boolean]
      def recent?(threshold: 60.0) = age < threshold

      # Whether multiple attempts were made.
      # @return [Boolean]
      def retried? = attempts > 1

      # Serializable hash representation.
      # @return [Hash]
      def to_h
        {
          request_id: request.id,
          error:,
          error_message:,
          attempts:,
          failed_at: failed_at.iso8601
        }
      end

      class << self
        # Creates a failed request record from an error.
        #
        # @param request [QueuedRequest] The original request
        # @param error [StandardError] The error that occurred
        # @param attempts [Integer] Number of execution attempts
        # @return [FailedRequest]
        def from_error(request:, error:, attempts: 1)
          new(
            request:,
            error: error.class.name,
            error_message: error.message,
            attempts:,
            failed_at: Time.now
          )
        end
      end
    end
  end
end
