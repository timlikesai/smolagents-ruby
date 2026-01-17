module Smolagents
  module Types
    module Ractor
      # Aggregated result from orchestrated parallel execution.
      #
      # @example Checking orchestrator results
      #   result = orchestrator.run_parallel(tasks)
      #   if result.all_success?
      #     puts "All #{result.success_count} tasks succeeded"
      #   else
      #     puts "#{result.failure_count} tasks failed"
      #   end
      OrchestratorResult = Data.define(:succeeded, :failed, :duration) do
        # Creates an OrchestratorResult with frozen result collections.
        #
        # @param succeeded [Array<RactorSuccess>] successfully completed tasks
        # @param failed [Array<RactorFailure>] failed tasks
        # @param duration [Numeric] total execution duration in seconds
        # @return [OrchestratorResult] a new aggregated result instance
        def self.create(succeeded:, failed:, duration:)
          new(succeeded: succeeded.freeze, failed: failed.freeze, duration:)
        end

        def all_success? = failed.empty?
        def any_success? = succeeded.any?
        def all_failed? = succeeded.empty? && failed.any?

        # Returns the number of successful task results.
        # @return [Integer] count of succeeded tasks
        def success_count = succeeded.size

        # Returns the number of failed task results.
        # @return [Integer] count of failed tasks
        def failure_count = failed.size

        # Returns the total number of tasks (succeeded + failed).
        # @return [Integer] total task count
        def total_count = succeeded.size + failed.size

        # Returns the total tokens used across all succeeded tasks.
        # @return [Integer] total tokens used
        def total_tokens
          succeeded.sum { |r| r.token_usage&.total_tokens || 0 }
        end

        # Returns the total steps taken across all tasks.
        # @return [Integer] total steps across all tasks
        def total_steps
          succeeded.sum(&:steps_taken) + failed.sum(&:steps_taken)
        end

        # Returns the output from each successful task.
        # @return [Array<Object>] list of outputs from succeeded tasks
        def outputs = succeeded.map(&:output)

        # Returns the error message from each failed task.
        # @return [Array<String>] list of error messages from failed tasks
        def errors = failed.map(&:error_message)

        # Deconstructs the result for pattern matching.
        #
        # @param _ [Object] ignored
        # @return [Hash{Symbol => Object}] hash with aggregated statistics
        def deconstruct_keys(_)
          { succeeded:, failed:, duration:, all_success: all_success?, success_count:, failure_count: }
        end
      end
    end

    # Re-export at Types level for backwards compatibility
    OrchestratorResult = Ractor::OrchestratorResult
  end
end
