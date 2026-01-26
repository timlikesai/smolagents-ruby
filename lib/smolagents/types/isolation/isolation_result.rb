module Smolagents
  module Types
    module Isolation
      # Error raised when execution times out.
      class TimeoutError < StandardError; end

      # Valid status values for IsolationResult.
      ISOLATION_STATUSES = %i[success timeout violation error].freeze

      # Result of isolated tool execution with status and metrics.
      #
      # Encapsulates the outcome of sandboxed execution including success/failure
      # status, the result value, resource metrics, and any error that occurred.
      # Use factory methods and predicates for clean result handling.
      #
      # @example Successful execution
      #   result = IsolationResult.success(value: "search results", metrics:)
      #   result.success?  # => true
      #   result.value     # => "search results"
      #
      # @example Handling timeout
      #   result = IsolationResult.timeout(metrics:)
      #   result.timeout?  # => true
      #   result.error     # => TimeoutError
      #
      # @example Pattern matching
      #   case result
      #   in IsolationResult[status: :success, value:]
      #     handle_success(value)
      #   in IsolationResult[status: :timeout]
      #     handle_timeout
      #   in IsolationResult[status: :violation, error:]
      #     handle_violation(error)
      #   in IsolationResult[status: :error, error:]
      #     handle_error(error)
      #   end
      #
      # @see ResourceLimits For limit definitions
      # @see ResourceMetrics For captured metrics
      IsolationResult = Data.define(:status, :value, :metrics, :error) do
        include TypeSupport::Deconstructable

        # Creates a successful result.
        #
        # @param value [Object] The execution result value
        # @param metrics [ResourceMetrics] Captured resource metrics
        # @return [IsolationResult] Success result
        def self.success(value:, metrics:)
          new(status: :success, value:, metrics:, error: nil)
        end

        # Creates a timeout result.
        #
        # @param metrics [ResourceMetrics] Captured resource metrics
        # @param error [Exception, nil] Optional timeout error
        # @return [IsolationResult] Timeout result
        def self.timeout(metrics:, error: nil)
          new(status: :timeout, value: nil, metrics:, error: error || TimeoutError.new("Execution timed out"))
        end

        # Creates a resource violation result.
        #
        # @param metrics [ResourceMetrics] Captured resource metrics
        # @param error [Exception] Error describing the violation
        # @return [IsolationResult] Violation result
        def self.violation(metrics:, error:)
          new(status: :violation, value: nil, metrics:, error:)
        end

        # Creates an error result.
        #
        # @param error [Exception] The error that occurred
        # @param metrics [ResourceMetrics, nil] Captured resource metrics
        # @return [IsolationResult] Error result
        def self.error(error:, metrics: nil)
          new(status: :error, value: nil, metrics: metrics || ResourceMetrics.zero, error:)
        end

        # Checks if execution succeeded.
        #
        # @return [Boolean] True if status is :success
        def success? = status == :success

        # Checks if execution timed out.
        #
        # @return [Boolean] True if status is :timeout
        def timeout? = status == :timeout

        # Checks if resource limit was violated.
        #
        # @return [Boolean] True if status is :violation
        def violation? = status == :violation

        # Checks if execution encountered an error.
        #
        # @return [Boolean] True if status is :error
        def error? = status == :error

        # Checks if execution failed (not successful).
        #
        # @return [Boolean] True if status is not :success
        def failed? = status != :success

        # Converts to hash for serialization.
        #
        # @return [Hash] Hash with all result fields
        def to_h
          {
            status:,
            value:,
            metrics: metrics&.to_h,
            error: error&.message
          }
        end
      end
    end
  end
end
