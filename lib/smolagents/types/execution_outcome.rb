module Smolagents
  module Types
    # Shared predicate methods for all execution outcome types.
    #
    # Include this module in Data.define blocks to get consistent state predicates
    # without code duplication. Requires the including type to have a `state` field.
    #
    # @example Including in a Data.define
    #   MyOutcome = Data.define(:state, :value) do
    #     include OutcomePredicates
    #   end
    module OutcomePredicates
      # @return [Boolean] True if execution completed successfully
      def success? = state == :success

      # @return [Boolean] True if agent reached final answer
      def final_answer? = state == :final_answer

      # @return [Boolean] True if execution failed with error
      def error? = state == :error

      # @return [Boolean] True if agent exceeded max steps
      def max_steps? = state == :max_steps_reached

      # @return [Boolean] True if execution timed out
      def timeout? = state == :timeout

      # @return [Boolean] True if execution completed (success or final_answer)
      def completed? = success? || final_answer?

      # @return [Boolean] True if execution failed (error, max_steps, timeout)
      def failed? = error? || max_steps? || timeout?
    end

    # Immutable execution outcome for any operation.
    #
    # ExecutionOutcome is the foundation of smolagents' event-driven architecture.
    # Every operation produces an outcome, which flows through the system via events.
    # This separates control flow (pattern matching on outcomes) from observability
    # (instrumentation emitting outcome events).
    #
    # Use the `metadata` field to store domain-specific data (tool name, step number,
    # run result, etc.) rather than creating specialized subclasses.
    #
    # @example Pattern matching
    #   case outcome
    #   in ExecutionOutcome[state: :success, value:]
    #     puts "Success: #{value}"
    #   in ExecutionOutcome[state: :error, error:]
    #     puts "Error: #{error.message}"
    #   end
    #
    # @example With domain-specific metadata
    #   outcome = ExecutionOutcome.success(value, metadata: { tool_name: "search", args: { q: "test" } })
    #   outcome.metadata[:tool_name]  # => "search"
    #
    # @example Async with Thread::Queue
    #   result_queue = Thread::Queue.new
    #   Thread.new do
    #     outcome = agent.run_with_outcome(task)
    #     result_queue.push(outcome)
    #   end
    #   outcome = result_queue.pop  # Block until complete, no sleep!
    #
    ExecutionOutcome = Data.define(
      :state,      # :success, :final_answer, :error, :max_steps_reached, :timeout
      :value,      # The successful result value (for :success, :final_answer)
      :error,      # The error object (for :error)
      :duration,   # Execution time in seconds
      :metadata    # Additional context (Hash) for domain-specific data
    ) do
      include OutcomePredicates

      # Get the result value, raising if execution failed.
      #
      # @return [Object] The value from successful execution
      # @raise [StandardError] The error if execution failed
      def value!
        raise error if error?
        raise StandardError, "Operation failed: #{state}" if failed?

        value
      end

      # Creates a success outcome.
      #
      # @param value [Object] The successful result
      # @param duration [Float] Execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutionOutcome] Success outcome
      def self.success(value, duration: 0.0, metadata: {})
        new(state: :success, value: value, error: nil, duration: duration, metadata: metadata)
      end

      # Creates a final answer outcome.
      #
      # @param value [Object] The final answer
      # @param duration [Float] Execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutionOutcome] Final answer outcome
      def self.final_answer(value, duration: 0.0, metadata: {})
        new(state: :final_answer, value: value, error: nil, duration: duration, metadata: metadata)
      end

      # Creates an error outcome.
      #
      # @param error [StandardError] The error that occurred
      # @param duration [Float] Execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutionOutcome] Error outcome
      def self.error(error, duration: 0.0, metadata: {})
        new(state: :error, value: nil, error: error, duration: duration, metadata: metadata)
      end

      # Creates a max steps outcome.
      #
      # @param steps_taken [Integer] Number of steps executed
      # @param duration [Float] Total execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutionOutcome] Max steps outcome
      def self.max_steps(steps_taken:, duration: 0.0, metadata: {})
        new(
          state: :max_steps_reached,
          value: nil,
          error: nil,
          duration: duration,
          metadata: metadata.merge(steps_taken: steps_taken)
        )
      end

      # Creates a timeout outcome.
      #
      # @param duration [Float] Time before timeout in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutionOutcome] Timeout outcome
      def self.timeout(duration: 0.0, metadata: {})
        new(state: :timeout, value: nil, error: nil, duration: duration, metadata: metadata)
      end

      # Converts outcome to event payload for instrumentation.
      #
      # Subclasses should override to include their specific fields.
      #
      # @return [Hash] Event payload with outcome data
      def to_event_payload
        {
          outcome: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata
        }.tap do |payload|
          payload[:value] = value if completed?
          payload[:error] = error.class.name if error?
          payload[:error_message] = error.message if error?
        end
      end
    end
  end
end
