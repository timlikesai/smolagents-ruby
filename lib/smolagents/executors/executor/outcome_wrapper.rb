module Smolagents
  module Executors
    class Executor
      # Concern for wrapping execution results in outcome objects.
      #
      # Provides execute_with_outcome which adds state machine semantics
      # and timing information to execution results.
      #
      # @example Including in an executor
      #   class MyExecutor < Executor
      #     include OutcomeWrapper
      #   end
      module OutcomeWrapper
        # Executes code and returns CodeOutcome (composition pattern).
        #
        # Wraps the ExecutionResult in an CodeOutcome, adding
        # state machine semantics and timing information.
        #
        # @param code [String] Source code to execute
        # @param language [Symbol] Programming language
        # @param timeout [Integer] Maximum execution time in seconds
        # @param memory_mb [Integer] Maximum memory usage in MB
        # @return [Types::CodeOutcome] Outcome with result and duration
        def execute_with_outcome(code, language:, timeout: 5, memory_mb: 256, **)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = execute(code, language:, timeout:, memory_mb:, **)
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          Types::CodeOutcome.from_result(result, duration:)
        end
      end
    end
  end
end
