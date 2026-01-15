module Smolagents
  module Types
    # Outcome for executor-level code execution.
    #
    # Wraps the result from code execution (ExecutionResult) with state machine
    # semantics (success/error/final_answer) and timing. Uses composition pattern,
    # storing the original result for inspection by observers.
    #
    # This bridges the gap between raw executor output and agent state semantics.
    #
    # @example Pattern matching on executor outcome
    #   case outcome
    #   in ExecutorExecutionOutcome[state: :success, result:]
    #     puts "Code output: #{result.output}"
    #   in ExecutorExecutionOutcome[state: :final_answer, result:]
    #     finalize(:success, result.output, context)
    #   in ExecutorExecutionOutcome[state: :error, error:]
    #     handle_error(error)
    #   end
    #
    # @example Creating from ExecutionResult
    #   exec_result = ExecutionResult.success(output: "42", logs: "computing...")
    #   outcome = ExecutorExecutionOutcome.from_result(exec_result, duration: 0.5)
    #
    # @see ExecutionResult For the wrapped executor result
    # @see ExecutionOutcome For base outcome semantics
    ExecutorExecutionOutcome = Data.define(
      :state, :value, :error, :duration, :metadata,
      :result # ExecutionResult from executor (contains output, logs, error, is_final_answer)
    ) do
      include OutcomePredicates

      # Gets output from the contained execution result.
      #
      # @return [String, nil] The code execution output
      # @example
      #   outcome.output  # => "42"
      def output = result&.output

      # Gets logs from the contained execution result.
      #
      # @return [String, nil] Captured execution logs
      # @example
      #   outcome.logs  # => "Debugging info..."
      def logs = result&.logs

      # Creates outcome from an ExecutionResult.
      #
      # Automatically determines state based on whether result has final_answer
      # or error set. Extracts output and error for storage.
      #
      # @param result [ExecutionResult] The executor result to wrap
      # @param duration [Float] Execution time in seconds
      # @param metadata [Hash] Additional domain-specific context
      # @return [ExecutorExecutionOutcome] Outcome wrapping the result
      # @example
      #   result = ExecutionResult.success(output: "42", logs: "...")
      #   outcome = ExecutorExecutionOutcome.from_result(result, duration: 0.5)
      def self.from_result(result, duration: 0.0, metadata: {})
        state = if result.is_final_answer
                  :final_answer
                elsif result.success?
                  :success
                else
                  :error
                end

        new(
          state:,
          value: result.output,
          error: result.error ? StandardError.new(result.error) : nil,
          duration:,
          metadata:,
          result:
        )
      end

      # Converts to event payload for instrumentation.
      #
      # Extends ExecutionOutcome payload to include executor-specific fields
      # (output and logs from the contained result).
      #
      # @return [Hash] Event payload with executor-specific data
      # @example
      #   payload = outcome.to_event_payload
      #   # => { outcome: :success, output: "42", logs: "...", ... }
      def to_event_payload
        base_payload.merge(conditional_payload).compact
      end

      private

      def base_payload
        { outcome: state, duration:, timestamp: Time.now.utc.iso8601,
          metadata:, output: result&.output, logs: result&.logs }
      end

      def conditional_payload
        { value: completed? ? value : nil,
          error: error? ? error.class.name : nil,
          error_message: error? ? error.message : nil }
      end
    end
  end
end
