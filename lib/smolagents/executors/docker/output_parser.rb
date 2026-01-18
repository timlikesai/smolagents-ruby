require "json"

module Smolagents
  module Executors
    class Docker < Executor
      # Output parsing and result building for Docker execution.
      #
      # Handles parsing Docker container output (JSON detection) and
      # building ExecutionResult objects.
      module OutputParser
        # Builds execution result from Docker output.
        #
        # @param stdout [String] Standard output from container
        # @param stderr [String] Standard error from container
        # @param status [Process::Status] Exit status
        # @return [ExecutionResult] Result with parsed output or error
        # @api private
        def build_execution_result(stdout, stderr, status)
          return build_result(output: parse_output(stdout), logs: stderr) if status.success?

          build_result(logs: stderr, error: "Exit code #{status.exitstatus}: #{stderr}")
        end

        # Parses Docker output.
        #
        # Automatically detects and parses JSON output if the output
        # starts with "{" or "[". Otherwise returns trimmed string.
        # JSON parse errors gracefully fall back to string.
        #
        # @param output [String] Output from docker container
        # @param _language [Symbol] Language (unused, for API compatibility)
        # @return [Object] Parsed JSON or string
        # @api private
        def parse_output(output, _language = nil)
          return JSON.parse(output) if output.start_with?("{", "[")

          output.strip
        rescue JSON::ParserError
          output.strip
        end

        # Builds an ExecutionResult for Docker execution.
        #
        # @param output [Object] Parsed output from container
        # @param logs [String] stderr output from container
        # @param error [String, nil] Error message if execution failed
        # @return [ExecutionResult] Result object
        # @api private
        def build_result(output: nil, logs: "", error: nil)
          Executor::ExecutionResult.new(output:, logs:, error:, is_final_answer: false)
        end
      end
    end
  end
end
