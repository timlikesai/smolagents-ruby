module Smolagents
  module Testing
    # Marker for queued failures in MockModel.
    #
    # Used internally to distinguish failures from normal responses
    # in the response queue. When next_response encounters a FailureMarker,
    # it raises the associated error.
    #
    # @example Queuing a failure
    #   marker = FailureMarker.new(NetworkError, "Connection refused")
    #   # When processed, raises: NetworkError.new("Connection refused")
    #
    # @see MockModel#queue_failure
    # @see MockModel#fail_next
    FailureMarker = Data.define(:error_class, :message) do
      # Create a new FailureMarker.
      #
      # @param error_class [Class, Exception] Error class or instance to raise
      # @param message [String, nil] Error message (ignored if error_class is an instance)
      def self.create(error_class, message = nil)
        new(error_class:, message:)
      end

      # Raise the error represented by this marker.
      #
      # @raise [Exception] The configured error
      def raise!
        case error_class
        when Class
          raise error_class, message || "MockModel failure injection"
        else
          # error_class is already an exception instance
          raise error_class
        end
      end

      # Check if this marker represents a specific error class.
      #
      # @param klass [Class] Error class to check
      # @return [Boolean]
      def error_type?(klass)
        case error_class
        when Class then error_class <= klass
        else error_class.is_a?(klass)
        end || false
      end
    end
  end
end
