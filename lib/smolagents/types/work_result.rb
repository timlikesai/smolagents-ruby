module Smolagents
  module Types
    # Result of processing a WorkItem.
    #
    # WorkResult captures the outcome of any work item execution, including
    # success/failure state, the return value or error, timing metrics, and
    # optional additional metrics for observability.
    #
    # @example Successful result
    #   result = WorkResult.success(
    #     work_item_id: item.id,
    #     value: response,
    #     duration_ms: 150
    #   )
    #   result.success?  # => true
    #   result.value     # => response
    #
    # @example Failed result
    #   result = WorkResult.error(
    #     work_item_id: item.id,
    #     error: StandardError.new("API timeout"),
    #     duration_ms: 30_000
    #   )
    #   result.error?         # => true
    #   result.error_message  # => "API timeout"
    #
    # @example Pattern matching on outcome
    #   case result
    #   in WorkResult[outcome: :success, value:]
    #     process_success(value)
    #   in WorkResult[outcome: :error, error:]
    #     handle_error(error)
    #   in WorkResult[outcome: :cancelled]
    #     log_cancellation
    #   end
    #
    # @see WorkItem For the input work unit
    # @see Concerns::Orchestration::WorkQueue For queue management
    WorkResult = Data.define(:work_item_id, :outcome, :value, :error, :duration_ms, :metrics) do
      include TypeSupport::Deconstructable

      # Valid outcome states
      OUTCOMES = %i[success error timeout cancelled].freeze

      include TypeSupport::StatePredicates

      state_predicates :outcome,
                       success: :success, error: :error,
                       timeout: :timeout, cancelled: :cancelled,
                       completed: %i[success error timeout]

      # @return [Boolean] True if work did not succeed
      def failed? = !success?

      # Extract the error message if present.
      # @return [String, nil] The error message, or nil if no error
      def error_message = error&.message

      # Duration in seconds.
      # @return [Float] Duration converted to seconds
      def duration_seconds = duration_ms / 1000.0

      # Get a metric value by key.
      # @param key [Symbol] The metric key
      # @return [Object, nil] The metric value, or nil if not present
      def metric(key) = metrics&.dig(key)

      class << self
        # Creates a successful result.
        #
        # @param work_item_id [String] UUID of the completed work item
        # @param value [Object] The result value
        # @param duration_ms [Integer] Execution duration in milliseconds
        # @param metrics [Hash] Optional additional metrics
        # @return [WorkResult]
        def success(work_item_id:, value:, duration_ms:, metrics: {})
          new(
            work_item_id:,
            outcome: :success,
            value:,
            error: nil,
            duration_ms:,
            metrics: metrics.freeze
          )
        end

        # Creates an error result.
        #
        # @param work_item_id [String] UUID of the failed work item
        # @param error [Exception] The error that occurred
        # @param duration_ms [Integer] Execution duration in milliseconds
        # @param metrics [Hash] Optional additional metrics
        # @return [WorkResult]
        def error(work_item_id:, error:, duration_ms:, metrics: {})
          new(
            work_item_id:,
            outcome: :error,
            value: nil,
            error:,
            duration_ms:,
            metrics: metrics.freeze
          )
        end

        # Creates a timeout result.
        #
        # @param work_item_id [String] UUID of the timed out work item
        # @param duration_ms [Integer] Duration before timeout
        # @param metrics [Hash] Optional additional metrics
        # @return [WorkResult]
        def timeout(work_item_id:, duration_ms:, metrics: {})
          new(
            work_item_id:,
            outcome: :timeout,
            value: nil,
            error: nil,
            duration_ms:,
            metrics: metrics.freeze
          )
        end

        # Creates a cancelled result.
        #
        # @param work_item_id [String] UUID of the cancelled work item
        # @param duration_ms [Integer] Duration before cancellation
        # @param metrics [Hash] Optional additional metrics
        # @return [WorkResult]
        def cancelled(work_item_id:, duration_ms: 0, metrics: {})
          new(
            work_item_id:,
            outcome: :cancelled,
            value: nil,
            error: nil,
            duration_ms:,
            metrics: metrics.freeze
          )
        end
      end
    end
  end
end
