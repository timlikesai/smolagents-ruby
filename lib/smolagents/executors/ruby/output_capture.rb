require "stringio"

module Smolagents
  module Executors
    class LocalRuby < Executor
      # Output capturing and result building for code execution.
      #
      # Handles stdout capture via StringIO, result construction,
      # and error formatting with secret redaction.
      #
      # @api private
      module OutputCapture
        # Executes validated code with output capture and error handling.
        #
        # Creates a StringIO buffer, validates Ruby code safety,
        # runs code in sandbox with operation limits, and builds result.
        #
        # @param code [String] Ruby code to execute
        # @return [ExecutionResult] Result with output, logs, and error
        def execute_validated_code(code)
          output_buffer = StringIO.new
          validate_ruby_code!(code)
          result = with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
          build_result(result, output_buffer.string)
        rescue FinalAnswerException => e
          build_final_answer_result(e, output_buffer)
        rescue InterpreterError => e
          build_error_result(Security::SecretRedactor.redact(e.message), output_buffer)
        rescue StandardError => e
          build_error_result(Security::SecretRedactor.redact("#{e.class}: #{e.message}"), output_buffer)
        end

        # Creates a new sandbox for code execution.
        #
        # Instantiates a Sandbox with all registered tools and variables.
        # The sandbox is a fresh instance for each execution.
        #
        # @param output_buffer [StringIO] Buffer to capture stdout
        # @return [Sandbox] A new sandbox instance
        def create_sandbox(output_buffer)
          Sandbox.new(tools:, variables:, output_buffer:)
        end

        private

        # Builds result for final_answer() calls.
        #
        # @param exception [FinalAnswerException] The final answer exception
        # @param output_buffer [StringIO] Captured output
        # @return [ExecutionResult] Result marked as final answer
        def build_final_answer_result(exception, output_buffer)
          build_result(exception.value, output_buffer.string, is_final: true)
        end

        # Builds result for execution errors.
        #
        # @param message [String] Error message (already redacted)
        # @param output_buffer [StringIO] Captured output before error
        # @return [ExecutionResult] Failed result with error
        def build_error_result(message, output_buffer)
          build_result(nil, output_buffer.string, error: message)
        end
      end
    end
  end
end
