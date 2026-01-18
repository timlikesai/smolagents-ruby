require "stringio"
require_relative "../tool_future"

module Smolagents
  module Executors
    class LocalRuby < Executor
      # Make ToolFuture and FutureBatch available
      FutureBatch = Executors::FutureBatch
      ToolFuture = Executors::ToolFuture
      # Output capturing and result building for code execution.
      #
      # Handles stdout capture via StringIO, result construction,
      # and error formatting with secret redaction.
      #
      # @api private
      module OutputCapture
        # Executes validated code with output capture and error handling.
        #
        # @param code [String] Ruby code to execute
        # @return [ExecutionResult] Result with output, logs, and error
        def execute_validated_code(code)
          output_buffer = StringIO.new
          result = run_sandboxed_code(code, output_buffer)
          build_result(result, output_buffer.string)
        rescue FinalAnswerException => e
          build_final_answer_result(e, output_buffer)
        rescue InterpreterError => e
          build_error_result(Security::SecretRedactor.redact(e.message), output_buffer)
        rescue StandardError => e
          build_error_result(Security::SecretRedactor.redact("#{e.class}: #{e.message}"), output_buffer)
        end

        def run_sandboxed_code(code, output_buffer)
          validate_ruby_code!(code)
          FutureBatch.clear!
          result = with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
          flush_pending_futures!
          resolve_if_future(result)
        end

        def flush_pending_futures!
          FutureBatch.pending.each(&:_execute!)
        end

        def resolve_if_future(value)
          return value unless value.is_a?(ToolFuture)

          value._result
        end

        # Creates a new sandbox for code execution.
        #
        # Instantiates a Sandbox with tracked tools and variables.
        # The sandbox is a fresh instance for each execution.
        # Tools are wrapped in tracking proxies to record calls.
        #
        # @param output_buffer [StringIO] Buffer to capture stdout
        # @return [Sandbox] A new sandbox instance
        def create_sandbox(output_buffer)
          tracked_tools = wrap_tools_for_tracking(tools)
          Sandbox.new(tools: tracked_tools, variables:, output_buffer:)
        end

        private

        # Builds result for final_answer() calls.
        #
        # Guards against short-circuiting: if the model called search/retrieval
        # tools in the same code block as final_answer, it hasn't seen the
        # results yet. Returns an error result to force multi-step behavior.
        #
        # @param exception [FinalAnswerException] The final answer exception
        # @param output_buffer [StringIO] Captured output
        # @return [ExecutionResult] Result marked as final answer, or error if blocked
        def build_final_answer_result(exception, output_buffer)
          warn "[guard] build_final_answer_result called" if ENV["SMOLAGENTS_DEBUG"]
          validate_no_pending_results!
          build_result(exception.value, output_buffer.string, is_final: true)
        rescue InterpreterError => e
          warn "[guard] BLOCKED: #{e.message}" if ENV["SMOLAGENTS_DEBUG"]
          build_error_result(Security::SecretRedactor.redact(e.message), output_buffer)
        end

        # Validates no search/retrieval tools were called before final_answer.
        #
        # @raise [InterpreterError] If retrieval tools were called
        def validate_no_pending_results!
          retrieval_tools = tool_calls.select { |c| retrieval_tool?(c.tool_name) }
          log_guard_debug(retrieval_tools)
          return if retrieval_tools.empty?

          names = retrieval_tools.map(&:tool_name).uniq.join(", ")
          raise InterpreterError, retrieval_guard_message(names)
        end

        def log_guard_debug(retrieval_tools)
          return unless ENV["SMOLAGENTS_DEBUG"]

          warn "[guard] tool_calls: #{tool_calls.map(&:tool_name).inspect}"
          warn "[guard] retrieval_tools: #{retrieval_tools.map(&:tool_name).inspect}"
        end

        def retrieval_guard_message(names)
          "Cannot call final_answer in the same step as #{names}. " \
            "You must WAIT to see the results before answering."
        end

        # Tools that return data you need to observe before answering.
        RETRIEVAL_TOOLS = %w[
          wikipedia web_search duckduckgo_search search web fetch
          google_search bing_search http_request
        ].freeze

        # Checks if a tool requires observation before final_answer.
        def retrieval_tool?(name)
          name_lower = name.to_s.downcase
          RETRIEVAL_TOOLS.any? { |t| name_lower.include?(t) }
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
