module Smolagents
  module Orchestrators
    # Collects and wraps results from Ractor executions.
    #
    # Handles the conversion of raw Ractor results into typed
    # RactorSuccess and RactorFailure objects.
    module ResultCollector
      module_function

      # Collects results from multiple Ractors.
      #
      # @param ractor_data [Array<Hash>] Array of {ractor:, task:, start_time:}
      # @param _timeout [Integer] Overall timeout (reserved for future use)
      # @return [Array<RactorSuccess, RactorFailure>] Collected results
      def collect_results(ractor_data, _timeout)
        ractor_data.map { |data| collect_single_result(data) }
      end

      # Collects a single result from a Ractor.
      #
      # @param data [Hash] Hash with :ractor, :task, :start_time
      # @return [RactorSuccess, RactorFailure] The result
      def collect_single_result(data)
        result = wait_for_ractor_result(data[:ractor], data[:task], data[:start_time])
        cleanup_ractor(data[:ractor])
        result
      end

      # Waits for a Ractor to complete and wraps the result.
      #
      # @param ractor [Ractor] The Ractor to wait on
      # @param task [RactorTask] The task being executed
      # @param start_time [Float] Monotonic start time
      # @return [RactorSuccess, RactorFailure] The wrapped result
      def wait_for_ractor_result(ractor, task, start_time)
        raw_result = ractor.value
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        wrap_ractor_result(raw_result, task, duration)
      rescue Ractor::RemoteError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        create_ractor_error_failure(task, e, duration)
      end

      # Wraps a raw Ractor result into a typed result object.
      #
      # @param raw_result [Hash] Hash with :type, :task_id, etc.
      # @param _task [RactorTask] The original task (unused)
      # @param duration [Float] Execution duration
      # @return [RactorSuccess, RactorFailure] The typed result
      def wrap_ractor_result(raw_result, _task, duration)
        case raw_result[:type]
        when :success then build_ractor_success(raw_result, duration)
        when :failure then build_ractor_failure(raw_result, duration)
        else raise "Unexpected result type: #{raw_result.inspect}"
        end
      end

      # Builds a RactorSuccess from raw result data.
      #
      # @param result [Hash] Raw success data
      # @param duration [Float] Execution duration
      # @return [RactorSuccess] The success result
      def build_ractor_success(result, duration)
        Types::RactorSuccess.new(
          task_id: result[:task_id],
          output: result[:output],
          steps_taken: result[:steps_taken],
          token_usage: result[:token_usage],
          duration:,
          trace_id: result[:trace_id]
        )
      end

      # Builds a RactorFailure from raw result data.
      #
      # @param result [Hash] Raw failure data
      # @param duration [Float] Execution duration
      # @return [RactorFailure] The failure result
      def build_ractor_failure(result, duration)
        Types::RactorFailure.new(
          task_id: result[:task_id],
          error_class: result[:error_class],
          error_message: result[:error_message],
          steps_taken: 0,
          duration:,
          trace_id: result[:trace_id]
        )
      end

      # Creates a failure result from a Ractor error.
      #
      # @param task [RactorTask] The failed task
      # @param error [Ractor::RemoteError] The error
      # @param duration [Float] Execution duration
      # @return [RactorFailure] The failure result
      def create_ractor_error_failure(task, error, duration = 0)
        Types::RactorFailure.from_exception(
          task_id: task.task_id,
          error: error.cause || error,
          trace_id: task.trace_id,
          duration:
        )
      end

      # Builds the final orchestrator result from collected results.
      #
      # @param results [Array<RactorSuccess, RactorFailure>] All results
      # @param duration [Float] Total execution duration
      # @return [OrchestratorResult] The aggregated result
      def build_orchestrator_result(results, duration)
        succeeded = results.select(&:success?)
        failed = results.select(&:failure?)

        Types::OrchestratorResult.create(succeeded:, failed:, duration:)
      end

      # Cleans up a Ractor after execution.
      #
      # @param ractor [Ractor, nil] The Ractor to clean up
      def cleanup_ractor(ractor)
        return unless ractor

        ractor.close if ractor.respond_to?(:close)
      rescue StandardError
        # Ignore cleanup errors
      end
    end
  end
end
