module Smolagents
  module Types
    # Outcome for executor-level code execution.
    #
    # CONTAINS ExecutionResult from executors - composition pattern.
    # Adds state machine layer (success/error/final_answer) and timing.
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
    ExecutorExecutionOutcome = Data.define(
      :state, :value, :error, :duration, :metadata,
      :result # ExecutionResult from executor (contains output, logs, error, is_final_answer)
    ) do
      include OutcomePredicates

      # Delegates to contained result
      def output = result&.output
      def logs = result&.logs

      # Creates outcome from ExecutionResult
      # @param result [ExecutionResult] The executor result
      # @param duration [Float] Execution time in seconds
      # @param metadata [Hash] Additional context
      # @return [ExecutorExecutionOutcome]
      def self.from_result(result, duration: 0.0, metadata: {})
        state = if result.is_final_answer
                  :final_answer
                elsif result.success?
                  :success
                else
                  :error
                end

        new(
          state: state,
          value: result.output,
          error: result.error ? StandardError.new(result.error) : nil,
          duration: duration,
          metadata: metadata,
          result: result
        )
      end

      def to_event_payload
        {
          outcome: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata,
          output: result&.output,
          logs: result&.logs
        }.tap do |payload|
          payload[:value] = value if completed?
          payload[:error] = error.class.name if error?
          payload[:error_message] = error.message if error?
        end
      end
    end
  end
end
