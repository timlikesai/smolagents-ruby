require_relative "tool_pause"

module Smolagents
  module Executors
    # Fiber-based incremental code execution.
    #
    # Wraps code execution in a Fiber, yielding control back to the caller
    # after each tool call. This allows the agent to observe tool results
    # before the code continues (or before final_answer is called).
    #
    # == The Problem This Solves
    #
    # Without incremental execution, a model might generate:
    #   results = searxng_search(query: "Ruby tutorials")
    #   final_answer(answer: "Found tutorials!")  # Model never sees results!
    #
    # With incremental execution:
    #   1. Code runs until searxng_search completes
    #   2. Execution pauses, yielding ToolPause to the agent
    #   3. Agent observes the search results
    #   4. Agent decides: continue execution or re-prompt model
    #   5. If retrieval tool + final_answer in same code: block final_answer
    #
    # == Usage
    #
    # Include this concern in an executor to enable incremental execution:
    #
    #   class MyExecutor < Executor
    #     include IncrementalExecution
    #   end
    #
    # Then use execute_incrementally instead of running code directly:
    #
    #   executor.execute_incrementally(code) do |pause|
    #     # Handle each tool pause
    #     puts "Tool #{pause.tool_name} returned: #{pause.result}"
    #     :continue  # or :stop to halt execution
    #   end
    #
    # @see ToolPause The yield type for tool calls
    module IncrementalExecution
      # Tracks whether we're currently in incremental execution mode.
      # Thread-local to support concurrent execution.
      def self.in_fiber_context?
        Thread.current[:smolagents_incremental_fiber] == true
      end

      def self.fiber_context=(value)
        Thread.current[:smolagents_incremental_fiber] = value
      end

      # Executes code incrementally, yielding after each tool call.
      #
      # @param code [String] Ruby code to execute
      # @yield [ToolPause] Called after each tool completes
      # @yieldreturn [:continue, :stop] Whether to continue execution
      # @return [ExecutionResult] Final result after all pauses handled
      def execute_incrementally(code, &)
        return execute_non_incremental(code) unless block_given?

        run_fiber_with_pauses(create_execution_fiber(code), &)
      end

      private

      def run_fiber_with_pauses(fiber, pauses = [], &)
        result = resume_fiber(fiber)
        return build_incremental_result(result, pauses) unless fiber.alive?

        handle_fiber_result(fiber, result, pauses, &)
      end

      def handle_fiber_result(fiber, result, pauses, &)
        return build_incremental_result(result, pauses) unless result.is_a?(ToolPause)

        pauses << result
        return build_paused_result(result, pauses) if yield(result) == :stop

        run_fiber_with_pauses(fiber, pauses, &)
      end

      # Creates a Fiber for code execution with incremental context.
      def create_execution_fiber(code)
        Fiber.new do
          IncrementalExecution.fiber_context = true
          begin
            execute_in_sandbox(code)
          ensure
            IncrementalExecution.fiber_context = false
          end
        end
      end

      # Resumes a fiber, catching any errors.
      def resume_fiber(fiber)
        fiber.resume
      rescue FinalAnswerException => e
        { type: :final_answer, value: e.value }
      rescue StandardError => e
        { type: :error, error: e }
      end

      # Executes code in sandbox (to be implemented by including class).
      # This should run the code and return the result.
      def execute_in_sandbox(code)
        raise NotImplementedError, "#{self.class} must implement execute_in_sandbox"
      end

      # Fallback for non-incremental execution.
      def execute_non_incremental(code)
        execute(code, language: :ruby)
      end

      # Builds result when execution completed normally.
      def build_incremental_result(result, _pauses)
        case result
        in { type: :final_answer, value: }
          build_result(value, captured_logs, is_final: true)
        in { type: :error, error: }
          build_result(nil, captured_logs, error: "#{error.class}: #{error.message}")
        else
          build_result(result, captured_logs)
        end
      end

      # Builds result when execution was paused (e.g., after retrieval tool).
      def build_paused_result(pause, _pauses)
        # Return the last tool result as the output, marked as not final
        build_result(pause.result, captured_logs, is_final: false)
      end

      # Gets captured logs (to be provided by OutputCapture).
      def captured_logs
        @output_buffer&.string || ""
      end
    end
  end
end
