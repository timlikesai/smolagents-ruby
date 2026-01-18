module Smolagents
  module Executors
    class Executor
      # Concern for building execution results with output processing.
      #
      # Provides methods for constructing ExecutionResult instances with
      # proper truncation of logs to prevent memory exhaustion.
      #
      # @example Including in an executor
      #   class MyExecutor < Executor
      #     include ResultBuilder
      #   end
      module ResultBuilder
        def self.included(base)
          base.attr_reader :max_output_length
        end

        # Builds an ExecutionResult with output length truncation.
        #
        # Creates a result, ensuring logs don't exceed max_output_length bytes.
        # This prevents memory exhaustion from verbose output.
        #
        # @param output [Object] The execution result value
        # @param logs [String] Captured output to truncate and include
        # @param error [String, nil] Error message if execution failed
        # @param is_final [Boolean] Whether final_answer() was called
        # @return [ExecutionResult] A properly formatted result
        def build_result(output, logs, error: nil, is_final: false)
          ExecutionResult.new(
            output:,
            logs: truncate_logs(logs),
            error:,
            is_final_answer: is_final
          )
        end

        private

        def truncate_logs(logs)
          logs.to_s.byteslice(0, @max_output_length) || ""
        end
      end
    end
  end
end
