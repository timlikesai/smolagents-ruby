module Smolagents
  module Types
    module Ractor
      # Failed result from a sub-agent Ractor.
      #
      # @example Creating from exception
      #   failure = Types::RactorFailure.from_exception(
      #     task_id: task.task_id,
      #     error: exception,
      #     trace_id: task.trace_id
      #   )
      RactorFailure = Data.define(:task_id, :error_class, :error_message, :steps_taken, :duration, :trace_id) do
        # Creates a RactorFailure from an exception.
        #
        # @param task_id [String] the original task ID
        # @param error [StandardError] the exception that was raised
        # @param trace_id [String] trace ID for request tracking
        # @param steps_taken [Integer] number of steps taken before failure (default: 0)
        # @param duration [Numeric] execution duration in seconds (default: 0)
        # @return [RactorFailure] a new failure result instance
        def self.from_exception(task_id:, error:, trace_id:, steps_taken: 0, duration: 0)
          new(
            task_id:,
            error_class: error.class.name,
            error_message: error.message,
            steps_taken:,
            duration:,
            trace_id:
          )
        end

        def success? = false
        def failure? = true

        # Deconstructs the result for pattern matching.
        #
        # @param _ [Object] ignored
        # @return [Hash{Symbol => Object}] hash with success: false and all attributes
        def deconstruct_keys(_)
          { task_id:, error_class:, error_message:, steps_taken:, duration:, trace_id:, success: false }
        end
      end
    end

    # Re-export at Types level for backwards compatibility
    RactorFailure = Ractor::RactorFailure
  end
end
