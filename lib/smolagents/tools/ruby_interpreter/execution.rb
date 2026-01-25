module Smolagents
  module Tools
    class RubyInterpreterTool < Tool
      # Execution logic for running Ruby code.
      #
      # Handles the actual code execution through the RactorExecutor
      # and formats results for agent consumption.
      module Execution
        # Executes Ruby code and returns the result.
        #
        # The code runs in a Ractor-isolated environment.
        # Both stdout output and the final expression value are captured.
        #
        # @param code [String] Ruby code to execute
        # @return [String] Formatted result containing stdout and output value,
        #   or an error message if execution failed
        def execute(code:)
          result = @executor.execute(code, language: :ruby, timeout: @timeout)
          format_result(result)
        end

        private

        # Builds the RactorExecutor with resolved configuration.
        #
        # @return [RactorExecutor] Configured executor instance
        def build_executor
          RactorExecutor.new(
            max_operations: @max_operations,
            max_output_length: @max_output_length
          )
        end

        # Formats execution result for agent consumption.
        #
        # @param result [Executors::ExecutionResult] The execution result
        # @return [String] Formatted output string
        def format_result(result)
          if result.success?
            "Stdout:\n#{result.logs}\nOutput: #{result.output}"
          else
            "Error: #{result.error}"
          end
        end
      end
    end
  end
end
