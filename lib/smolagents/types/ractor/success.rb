module Smolagents
  module Types
    module Ractor
      # Successful result from a sub-agent Ractor.
      #
      # @example Creating from run result
      #   success = Types::RactorSuccess.from_result(
      #     task_id: task.task_id,
      #     run_result: result,
      #     duration: 2.5,
      #     trace_id: task.trace_id
      #   )
      RactorSuccess = Data.define(:task_id, :output, :steps_taken, :token_usage, :duration, :trace_id) do
        # Creates a RactorSuccess from a RunResult.
        #
        # @param task_id [String] the original task ID
        # @param run_result [Types::RunResult] the agent's run result
        # @param duration [Numeric] execution duration in seconds
        # @param trace_id [String] trace ID for request tracking
        # @return [RactorSuccess] a new success result instance
        def self.from_result(task_id:, run_result:, duration:, trace_id:)
          new(
            task_id:,
            output: run_result.output,
            steps_taken: run_result.steps&.size || 0,
            token_usage: run_result.token_usage,
            duration:,
            trace_id:
          )
        end

        def success? = true
        def failure? = false

        # Deconstructs the result for pattern matching.
        #
        # @param _ [Object] ignored
        # @return [Hash{Symbol => Object}] hash with success: true and all attributes
        def deconstruct_keys(_)
          { task_id:, output:, steps_taken:, token_usage:, duration:, trace_id:, success: true }
        end
      end
    end

    # Re-export at Types level for backwards compatibility
    RactorSuccess = Ractor::RactorSuccess
  end
end
