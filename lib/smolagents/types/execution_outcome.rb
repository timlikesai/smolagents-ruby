module Smolagents
  module Types
    # Shared predicate methods for all execution outcome types.
    #
    # Include this module in Data.define blocks to get consistent state predicates
    # without code duplication. Requires the including type to have a `state` field.
    #
    # Provides state checking methods for outcomes, supporting various state
    # symbols (:success, :error, :final_answer, :max_steps_reached, :timeout).
    #
    # @example Including in a Data.define
    #   MyOutcome = Data.define(:state, :value) do
    #     include OutcomePredicates
    #   end
    #
    # @see ExecutionOutcome For concrete usage
    module OutcomePredicates
      # Checks if execution completed successfully.
      #
      # @return [Boolean] True if state is :success
      # @example
      #   outcome.success?  # => true
      def success? = state == :success

      # Checks if execution reached final answer.
      #
      # @return [Boolean] True if state is :final_answer
      # @example
      #   outcome.final_answer?  # => true
      def final_answer? = state == :final_answer

      # Checks if execution failed with error.
      #
      # @return [Boolean] True if state is :error
      # @example
      #   outcome.error?  # => true
      def error? = state == :error

      # Checks if execution exceeded step limit.
      #
      # @return [Boolean] True if state is :max_steps_reached
      # @example
      #   outcome.max_steps?  # => true
      def max_steps? = state == :max_steps_reached

      # Checks if execution timed out.
      #
      # @return [Boolean] True if state is :timeout
      # @example
      #   outcome.timeout?  # => true
      def timeout? = state == :timeout

      # Checks if execution completed (success or final answer).
      #
      # @return [Boolean] True if completed successfully
      # @example
      #   outcome.completed?  # => true
      def completed? = success? || final_answer?

      # Checks if execution failed (error, max steps, or timeout).
      #
      # @return [Boolean] True if failed
      # @example
      #   outcome.failed?  # => true
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

      # Gets the result value, raising if execution failed.
      #
      # Unwraps the value from a successful outcome, or raises the error
      # from a failed outcome. Useful in contexts where you want exceptions
      # instead of outcome values.
      #
      # @return [Object] The value from successful execution
      # @raise [StandardError] The error if execution failed
      # @example
      #   outcome = operation()
      #   result = outcome.value!  # Raises if outcome.error?
      def value!
        raise error if error?
        raise StandardError, "Operation failed: #{state}" if failed?

        value
      end

      # Creates a success outcome.
      #
      # Indicates operation completed successfully with a value.
      #
      # @param value [Object] The successful result value
      # @param duration [Float] Execution time in seconds (default 0.0)
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutionOutcome] Success outcome
      # @example
      #   ExecutionOutcome.success("Result", duration: 1.5, metadata: { tool: "search" })
      def self.success(value, duration: 0.0, metadata: {})
        new(state: :success, value:, error: nil, duration:, metadata:)
      end

      # Creates a final answer outcome.
      #
      # Indicates agent reached its final answer (distinct from generic success).
      # Used in agent flows where final_answer is a distinct terminal state.
      #
      # @param value [Object] The final answer value
      # @param duration [Float] Execution time in seconds (default 0.0)
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutionOutcome] Final answer outcome
      # @example
      #   ExecutionOutcome.final_answer("42", duration: 2.5)
      # @see FinalAnswerTool For agents that produce final answers
      def self.final_answer(value, duration: 0.0, metadata: {})
        new(state: :final_answer, value:, error: nil, duration:, metadata:)
      end

      # Creates an error outcome.
      #
      # Indicates operation failed with an exception.
      #
      # @param error [StandardError] The error that occurred
      # @param duration [Float] Execution time in seconds (default 0.0)
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutionOutcome] Error outcome
      # @example
      #   ExecutionOutcome.error(RuntimeError.new("Connection failed"), duration: 0.5)
      def self.error(error, duration: 0.0, metadata: {})
        new(state: :error, value: nil, error:, duration:, metadata:)
      end

      # Creates a max steps outcome.
      #
      # Indicates operation was cut short due to reaching step limit.
      # The metadata automatically includes steps_taken.
      #
      # @param steps_taken [Integer] Number of steps executed before limit
      # @param duration [Float] Total execution time in seconds (default 0.0)
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutionOutcome] Max steps outcome
      # @example
      #   ExecutionOutcome.max_steps(steps_taken: 10, duration: 5.0)
      def self.max_steps(steps_taken:, duration: 0.0, metadata: {})
        new(
          state: :max_steps_reached,
          value: nil,
          error: nil,
          duration:,
          metadata: metadata.merge(steps_taken:)
        )
      end

      # Creates a timeout outcome.
      #
      # Indicates operation exceeded time limit.
      #
      # @param duration [Float] Time before timeout in seconds
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutionOutcome] Timeout outcome
      # @example
      #   ExecutionOutcome.timeout(duration: 30.0)
      def self.timeout(duration: 0.0, metadata: {})
        new(state: :timeout, value: nil, error: nil, duration:, metadata:)
      end

      # Converts outcome to event payload for instrumentation.
      #
      # Provides a standardized format for events emitted by the system.
      # Includes outcome state, duration, timestamp, and conditional fields
      # for value/error based on outcome type.
      #
      # Subclasses can override to include additional outcome-specific fields.
      #
      # @return [Hash] Event payload with :outcome, :duration, :timestamp, :metadata,
      #                 and conditionally :value, :error, :error_message
      # @example
      #   payload = outcome.to_event_payload
      #   # => { outcome: :success, duration: 1.5, timestamp: "2024-01-13T...", value: "..." }
      # @see Telemetry#emit For event emission
      def to_event_payload
        base_payload.merge(conditional_payload).compact
      end

      # Enables pattern matching with `in ExecutionOutcome[state:, value:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      # @example Pattern matching
      #   outcome = Smolagents::Types::ExecutionOutcome.success("done", duration: 1.5)
      #   case outcome
      #   in { state: :success, value: v }
      #     v  # => "done"
      #   end
      def deconstruct_keys(_keys) = { state:, value:, error:, duration:, metadata: }

      private

      def base_payload = { outcome: state, duration:, timestamp: Time.now.utc.iso8601, metadata: }

      def conditional_payload
        return { value: } if completed?
        return { error: error.class.name, error_message: error.message } if error?

        {}
      end
    end
  end
end
